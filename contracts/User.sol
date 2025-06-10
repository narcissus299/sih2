pragma solidity ^0.4.21;

contract User {

    // Events
    event NewWorker(uint indexed userId, string username, uint exp_pts);
    event NewRequester(uint indexed userId, string username);
    event FundsDeposited(address indexed user, uint amount);
    event FundsWithdrawn(address indexed user, uint amount);
    event PaymentTransferred(address indexed from, address indexed to, uint amount);

    struct Worker {
        string username;
        string pwd;
        uint32 expPts;
        uint256 accountBalance; // Changed to uint256 to handle larger Ether amounts
    }

    struct Requester {
        string username;
        string pwd;
        uint256 accountBalance; // Changed to uint256 to handle larger Ether amounts
    }

    Worker[] public workers;
    Requester[] public requesters;

    mapping (uint => address) public workerAddress;
    mapping (uint => uint) public workerStatus;
    mapping (uint => address) public requesterAddress;
    
    // Track actual Ether balances
    mapping (address => uint256) public ethBalances;

    // Contract owner
    address public owner;
    
    // Constructor
    function User() public {
        owner = msg.sender;
    }
    
    // Modifier to check if caller is owner
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function _createWorker(string _name, string _pwd) public returns (uint) {
        uint id = workers.push(Worker(_name, _pwd, 0, 0)) - 1;
        workerAddress[id] = msg.sender;
        workerStatus[id] = 2;
        
        emit NewWorker(id, _name, 0);
        return id;
    }

    function _createRequester(string _name, string _pwd) public returns (uint) {
        uint id = requesters.push(Requester(_name, _pwd, 0)) - 1;
        requesterAddress[id] = msg.sender;
        
        emit NewRequester(id, _name);
        return id;
    }
    
    // Function to deposit funds
    function depositFunds() public payable {
        require(msg.value > 0, "Must send some Ether");
        ethBalances[msg.sender] += msg.value;
        emit FundsDeposited(msg.sender, msg.value);
    }
    
    // Function for requesters to deposit funds for tasks
    function depositTaskFunds(uint _requesterId) public payable {
        require(msg.sender == requesterAddress[_requesterId], "Only the requester can deposit funds");
        require(msg.value > 0, "Must send some Ether");
        
        requesters[_requesterId].accountBalance += msg.value;
        ethBalances[msg.sender] += msg.value;
        
        emit FundsDeposited(msg.sender, msg.value);
    }
    
    // Function to withdraw funds
    function withdrawFunds(uint amount) public {
        require(ethBalances[msg.sender] >= amount, "Insufficient balance");
        
        ethBalances[msg.sender] -= amount;
        msg.sender.transfer(amount);
        
        emit FundsWithdrawn(msg.sender, amount);
    }
    
    // Internal function to transfer funds between users
    function _transferFunds(address _from, address _to, uint _amount) internal {
        require(ethBalances[_from] >= _amount, "Insufficient balance");
        
        ethBalances[_from] -= _amount;
        ethBalances[_to] += _amount;
        
        emit PaymentTransferred(_from, _to, _amount);
    }
    
    // Function to check user balance
    function checkBalance() public view returns (uint256) {
        return ethBalances[msg.sender];
    }
    
    // Function for worker to check their experience points
    function checkWorkerExp(uint _workerId) public view returns (uint32) {
        require(msg.sender == workerAddress[_workerId], "Only the worker can check their exp");
        return workers[_workerId].expPts;
    }
    
    // Emergency function to recover funds (only owner)
    function emergencyWithdraw() public onlyOwner {
        owner.transfer(address(this).balance);
    }
}
