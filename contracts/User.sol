pragma solidity ^0.4.21;

contract User {

//event newWorker(uint userId, string username, uint exp_pts);
//event newRequester(uint userId, string username);

struct worker {

string username;
string pwd;
uint32 expPts;
uint32 accountBalance;
}

struct requester {

string username;
string pwd;
uint32 accountBalance;
}


worker[] public workers;
requester[] public requesters;

mapping (uint => address) public workerAddress;
mapping(uint => uint) public workerStatus;
mapping (uint => address) public requesterAddress;

function _createWorker(string _name, string _pwd) returns (uint) {

uint id = workers.push(worker(_name, _pwd, 0, 10))-1;
workerAddress[id] = msg.sender;
workerStatus[id] = 2;

return id;
//newWorker(id, _name, 0);
}

function _createRequester(string _name, string _pwd) returns (uint) {

uint id = requesters.push(requester(_name, _pwd, 10))-1;
requesterAddress[id] = msg.sender;

return id;
//newRequester(id, _name);
}

// function _checkAccount() private view returns(){
// }

// function displayUserStats() private view returns() {
// }

}
