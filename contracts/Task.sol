pragma solidity ^0.4.21;

import "./user.sol";

contract Task is User {

    struct Task {
    uint requesterId;
    uint32 taskDuration;
    uint expRequired;
    uint expAwarded;
    uint reward;
    uint postTime;
    }

    Task[] public tasks;

    //mapping(uint => uint) internal taskToRequester;
    mapping(uint => uint) internal applyForTask;
    mapping(uint => uint) internal taskAssignedTo;
    mapping(uint => uint) internal taskStatus;

    uint32 timeoutBegin;

    // Pending 1
    // Free 2
    // Unclaimed 3
    // Cancelled 4
    // Claimed 5
    // Submitted 6
    // Evaluated 7
    // Pending 8
    // Completed 9

    function generateTask(uint _requesterId)  {
        require(msg.sender == requesterAddress[_requesterId]);
        uint taskId = tasks.push(Task(_requesterId, 10 days, 100, 50, 5, uint32(now))) - 1;
        taskStatus[taskId] = 1;

        //new event for the new task
        //add a ether transaction?
      }

    function applyTask(uint taskId, uint _workerId)  {
        require(msg.sender == workerAddress[_workerId]);
        if(workerStatus[_workerId] == 2 && (workers[_workerId].expPts > tasks[taskId].expRequired)){
        applyForTask[_workerId] = taskId;}
    }

    function workerConfirm(uint taskId, uint _requesterId, uint _workerId)  {
        require(msg.sender == requesterAddress[_requesterId]);
        require(taskId == applyForTask[_workerId]);
        require(taskStatus[taskId] == 1);
        taskStatus[taskId] = 3;
        timeoutBegin = uint32(now);
        //define an event stating confirmation of worker.
    }

    function workerClaim(uint taskId, uint _workerId)  returns(bool){

        require(msg.sender == workerAddress[_workerId]);
        require(taskStatus[taskId] == 3);
        uint32 currentTime = uint32(now);
        if(taskStatus[taskId] == 3 && (currentTime > uint32(timeoutBegin + now))){
        taskStatus[taskId] = 4;
        return false;
        }

        taskAssignedTo[taskId] = _workerId;
        taskStatus[taskId] = 5;
        return true;

        //define event stating that the worker has accepted and started working
    }

    function submitTask(uint taskId, uint _workerId)  {

        require(msg.sender == workerAddress[_workerId]);
        require(taskStatus[taskId] == 5);
        taskStatus[taskId] = 6;

        //event update to requester tasks[taskId].requesterId
    }


    function rewardWorker(uint _workerId, uint taskId)  {

        workers[_workerId].accountBalance += uint32(tasks[taskId].reward);
        workers[_workerId].expPts += uint32(tasks[taskId].expAwarded);
        taskStatus[taskId] = 9;
        workerStatus[_workerId] = 2;


    }

    function acceptSubmission(uint _requesterId, uint taskId)  {

        require(msg.sender == requesterAddress[_requesterId]);
        require(taskStatus[taskId] == 6);
        taskStatus[taskId] = 7;
        rewardWorker(taskAssignedTo[taskId], taskId);

        //event stating that the task has been completed.
    }

    function rejectSubmission(uint _requesterId, uint taskId)  {

        require(msg.sender == requesterAddress[_requesterId]);
        require(taskStatus[taskId] == 6);
        taskStatus[taskId] = 1;

        //event stating task has been rejected
        }


    function displayPendingTasks()  view returns(uint[]) {

      uint[] memory pendingTasks;
      uint count = 0;
      for(uint i=0; i < tasks.length; i++) {
        if(taskStatus[i] == 1) {
        pendingTasks[count] = i;
        count++;
        }
      }
      return pendingTasks;
    }

 //define a function to turn cancelled task to pending
 //define a function to turn pending task to cancelled
}
