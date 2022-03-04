pragma solidity >=0.7.0 < 0.9.0;


contract CarRental {

    struct Car {
        string name;
        /*
        Car's price. 
        When customer rent a car, the customer must deposit money: price + (x + 1) * monthlyRent.
        */
        uint price;
        uint monthlyRent;
    }

    //will record the action involved with money
    // 
    struct customerRentCarRecord {
        uint rentRecordId;
        address customerAddress;
        string carName;
        uint rentMonth;
        uint totalMoneyDeposit;
        uint rentTimeStamp;
        int returnRecordId;
    }

    struct customerReturnCarRecord {
        uint returnRecordId;
        uint rentRecordId;
        address customerAddress;
        string carName;
        uint returnTimeStamp;
        uint rentFee;
        int auditRecordId;

    }

    struct ABCAuditDepositRecord {
        uint auditRecordId;
        uint returnRecordId;
        address customerAddress;
        uint damageFixFee;
        uint actualRefundAmount;

    }
    
    // company instace
    address public ABCAddress;

    // A mapping that stores all customers' addresses.
    // If an address exists, its value is true, else false.
    mapping (address => bool) public allCustomerAddresses;

    /* 
        This customer's renting car. 
        Customer's Address => Car's Name => This Car's Number
        e.g. Bob's renting 2 cars A. Bob's Address => 'A' => 2
    */
    mapping (address => mapping(string => uint)) public customerRentingCarNumber;


    // Cars' Info. Car's Name => Car's Info (a Car struct)
    mapping (string => Car) public carInfo;
    // Cars' availability. Car's Name => Available Number
    mapping (string => uint) public carAvailability;


    // All action history. 
    // Use allCustomerRentCarRecord[RentRecordId] to visit the record.
    uint public currentRentRecordId  = 1;
    mapping (uint => customerRentCarRecord) public allCustomerRentCarRecord;

    uint public currentReturnRecordId = 1;
    mapping (uint => customerReturnCarRecord) public allCustomerReturnCarRecord;

    uint public currentAuditRecordId = 1;
    mapping (uint => ABCAuditDepositRecord) public allABCAuditDepositRecord;



    /* 
    ABC company calls this function.
    ABC company deploys this contract.
    */
    constructor() {
        ABCAddress = msg.sender;
    }


    /* 
    Customer calls this function.
    Customer registers itself to this service. 
    Store this customer's address in allCustomerAddresses.
    */
    function customerRegister() public returns (bool) {
        allCustomerAddresses[msg.sender] = true;
        return true;
    }


    /* 
    ABC company calls this function.
    Abc company add cars to this contract. 
    Store car's info in carInfo. Update carAvailability.
    */
    function ABCAddCar(string calldata carName, uint carPrice, uint carMonthlyRent, uint number) public returns (bool) {
        require(msg.sender == ABCAddress, "Only ABC can add cars!");

        carInfo[carName] = Car({
            name: carName, 
            price: carPrice,
            monthlyRent: carMonthlyRent
        });

        carAvailability[carName] += number;

        return true;
    }



    /*
    Customer calls this function.
    Customer rent ONE car.
    Specify the carName and the rentMonth.
    */
    function customerRentCar(string calldata carName, uint rentMonth) payable public returns (customerRentCarRecord memory) {
        require(allCustomerAddresses[msg.sender] == true, "Customer not registered! Please register first!");
        require(carAvailability[carName] > 0, "No this type's cars available now!");
        require(msg.value >= (carInfo[carName].price + (rentMonth + 1) * carInfo[carName].monthlyRent), "Deposit is not enough! Deposit shoule be larger than price + (x + 1) * monthlyRent");

        // update customer renting car info
        customerRentingCarNumber[msg.sender][carName] += 1;
        // update car's availability info
        carAvailability[carName] -= 1;
        // generate a customerRentCarRecord and put the record into customerRentCarRecord
        customerRentCarRecord memory thisRentCarRecord = customerRentCarRecord(currentRentRecordId, msg.sender, carName, rentMonth, msg.value, block.timestamp, -1);
        allCustomerRentCarRecord[currentRentRecordId] = thisRentCarRecord;
        currentRentRecordId += 1;
        // customer pay eth to the ABCAddress as Deposit
        payable(ABCAddress).transfer(msg.value);

        return thisRentCarRecord;
    }
    

    /*
    Customer calls this function.
    According to given rentRecordId, customer returns the car to this specified rent record. 
    */
    function customerReturnCar(uint rentRecordId) public returns (customerReturnCarRecord memory) {
        require(rentRecordId <= currentRentRecordId && rentRecordId > 0, "Input rentRecordId Invaid!");
        require(msg.sender == allCustomerRentCarRecord[rentRecordId].customerAddress, "The customer's address doesn't matched!");
        require(allCustomerRentCarRecord[rentRecordId].returnRecordId == -1, "The rent of this rentId has been already returned!");
        
        // Retrieve some values.
        string memory carNameHere = allCustomerRentCarRecord[rentRecordId].carName;
        uint rentTimeStampHere = allCustomerRentCarRecord[rentRecordId].rentTimeStamp;
        
        // update customer renting car info
        customerRentingCarNumber[msg.sender][carNameHere] -= 1;
        // update car's availability info
        carAvailability[carNameHere] += 1;

        // Use timestamp to compute the actual 
        uint timeNow = block.timestamp;
        uint actualTimePassed =  timeNow - rentTimeStampHere;
        /* Calculate how many days passed. 
            Tructate the decimal part
            e.g. 1.2 day will be considered as 1 day */
        uint actualDayPassed = actualTimePassed / 60 / 60 / 24;
        /* Calculate how many months passed. 30 days = 1 month. 
            Round up.
            e.g. 2.5 month will be considered as 3 month */
        uint actualMonthPassed = actualDayPassed / 30;
        if (actualDayPassed % 30 > 0) {
            actualMonthPassed += 1;
        }

        // Compute rent fee.
        uint rentFeeHere = actualMonthPassed * carInfo[carNameHere].monthlyRent;
        
        // generate a customerReturnCarRecord and put the record into customerRentCarRecord
        customerReturnCarRecord memory thisReturnCarRecord = customerReturnCarRecord(currentReturnRecordId, 
                                                                                     rentRecordId, 
                                                                                     msg.sender, 
                                                                                     carNameHere, 
                                                                                     timeNow, 
                                                                                     rentFeeHere, 
                                                                                     -1);
        allCustomerReturnCarRecord[currentReturnRecordId] = thisReturnCarRecord;
        allCustomerRentCarRecord[rentRecordId].returnRecordId = int(currentReturnRecordId);
        currentReturnRecordId += 1;

        return thisReturnCarRecord;
    }

    /*
    ABC company calls this function.
     According to given returnRecordId, ABC companys checks the rentFee + damageFee and gives back the remained deposit to customer. 
     */
    function ABCAuditDeposit(uint returnRecordId, uint damageFixFeeHere) payable public returns (ABCAuditDepositRecord memory) {
        require(returnRecordId <= currentReturnRecordId && returnRecordId > 0, "Input returnRecordId Invaid!");
        require(msg.sender == ABCAddress, "Only ABC company can audit the deposit!");
        require(allCustomerReturnCarRecord[returnRecordId].auditRecordId == -1, "The return of this returnId has been already audited!");


        // Retrieve some values from rent&return record
        address customerAddressHere = allCustomerReturnCarRecord[returnRecordId].customerAddress;
        uint totalDepositHere = allCustomerRentCarRecord[allCustomerReturnCarRecord[returnRecordId].rentRecordId].totalMoneyDeposit;
        uint rentFeeHere = allCustomerReturnCarRecord[returnRecordId].rentFee;

        // Compute Remained Deposit that will be refunded to customer
        uint refundAmountHere = totalDepositHere - rentFeeHere - damageFixFeeHere;

        // Refund to customer
        payable(customerAddressHere).transfer(refundAmountHere);

        ABCAuditDepositRecord memory auditDepositRecordHere = ABCAuditDepositRecord(currentAuditRecordId, 
                                                                                    returnRecordId,
                                                                                    customerAddressHere, 
                                                                                    damageFixFeeHere, 
                                                                                    refundAmountHere);

        allABCAuditDepositRecord[currentAuditRecordId] = auditDepositRecordHere;
        allCustomerReturnCarRecord[returnRecordId].auditRecordId = int(currentAuditRecordId);
        currentAuditRecordId += 1;
        
        return auditDepositRecordHere;
    }

}