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


    // All action history
    uint public currentRentRecordId  = 1;
    mapping (uint => customerRentCarRecord) public allCustomerRentCarRecord;

    uint public currentReturnRecordId = 1;
    mapping (uint => customerReturnCarRecord) public allCustomerReturnCarRecord;

    uint public currentAuditRecordId = 1;
    mapping (uint => ABCAuditDepositRecord) public allABCAuditDepositRecord;




    constructor() {
        ABCAddress = msg.sender;
    }


    function customerRegister() public returns (bool) {
        allCustomerAddresses[msg.sender] = true;
        return true;
    }

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




    function customerRentCar(string calldata carName, uint rentMonth) payable public returns (customerRentCarRecord memory) {
        require(allCustomerAddresses[msg.sender] == true, "Customer not registered! Please register first!");
        require(carAvailability[carName] > 0, "No this type's cars available now!");
        require(msg.value >= (carInfo[carName].price + (rentMonth + 1) * carInfo[carName].monthlyRent), "Deposit is not enough! Deposit shoule be larger than price + (x + 1) * monthlyRent");

        customerRentingCarNumber[msg.sender][carName] += 1;
        carAvailability[carName] -= 1;
        customerRentCarRecord memory thisRentCarRecord = customerRentCarRecord(currentRentRecordId, msg.sender, carName, rentMonth, totalDeposit, block.timestamp, -1);
        allCustomerRentCarRecord[currentRentRecordId] = thisRentCarRecord;
        payable(ABCAddress).transfer(msg.value);
        return thisRentCarRecord;
    }
    



}