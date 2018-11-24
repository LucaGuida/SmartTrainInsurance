pragma solidity 0.4.24;
import "github.com/oraclize/ethereum-api/oraclizeAPI.sol";
contract SmartTrainInsurance is usingOraclize {
    struct InsurancePolicy {
      uint      id;
      address   owner;
      string    insuredItem;
      bool      entitledToCompensation;
      bool      conditionChecked;
      bool      paid;
    }
    address public owner;
    uint public constant PREMIUM = 20000000000000000;
    uint public constant COMPENSATION = 100000000000000000;
    uint public constant MIN_PUNCTUALITY = 90;
    uint public totalPotentialCompensation = 0;
    InsurancePolicy[] public policiesArray;
    mapping(string => bool) internal scheduledAPIcalls;
    mapping(string => uint[]) internal insuredItemPoliciesMap;
    mapping(bytes32 => string) internal oraclizeQueriesMap;
    mapping(string => uint) internal expirationDateMap;
    event LogNewOraclizeQuery(
        string  description
    );
    event LogAPIUpdated(
        string  description
    );
    event LogDepositReceived(
        address  sender
    );
    bool public paused = false;
    event OwnershipRenounced(address indexed previousOwner);
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    event Pause();
    event Unpause();
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
    modifier whenNotPaused() {
        require(!paused);
        _;
    }
    modifier whenPaused() {
        require(paused);
        _;
    }
    function renounceOwnership() public onlyOwner {
        emit OwnershipRenounced(owner);
        owner = address(0);
    }
    function transferOwnership(address _newOwner) public onlyOwner {
        _transferOwnership(_newOwner);
    }
    function _transferOwnership(address _newOwner) internal {
        require(_newOwner != address(0));
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }    
    function pause() onlyOwner whenNotPaused public {
        paused = true;
        emit Pause();
    }
    function unpause() onlyOwner whenPaused public {
        paused = false;
        emit Unpause();
    }
    function add(uint256 a, uint256 b) constant returns (uint256 c) {
        c = a + b;
        assert(c >= a);
        return c;
    }
    function sub(uint256 a, uint256 b) constant returns (uint256) {
        assert(b <= a);
        return a - b;
    }
    function() public payable { 
        require(msg.data.length == 0); 
        emit LogDepositReceived(msg.sender); 
    }
    constructor() public {
        owner = msg.sender;
        expirationDateMap["SEPT2018"] = 1538388000;
        expirationDateMap["AUG2018"] = 1535796000;
    }
    function getContractBalance() public view returns(uint) {
        return address(this).balance;
    }
    function increaseContractBalance() public payable onlyOwner {
        if (msg.value == 0) return;
        emit LogDepositReceived(msg.sender); 
    }
    function decreaseContractBalance(uint amount) public onlyOwner {
        if (sub(address(this).balance,amount)<totalPotentialCompensation) return;
        owner.transfer(amount);
    }
    function registerNewPolicy(string _insuredItem) public payable whenNotPaused {
        if (msg.value != PREMIUM) return; 
        if (add(address(this).balance,msg.value)<add(totalPotentialCompensation,COMPENSATION)) return; 
        InsurancePolicy policy;
        policy.id = policiesArray.length;
        policy.owner = msg.sender;
        policy.insuredItem = _insuredItem;
        policy.conditionChecked = false;
        policy.entitledToCompensation = false;
        policy.paid = false;
        policiesArray.push(policy);
        insuredItemPoliciesMap[policy.insuredItem].push(policy.id);
        totalPotentialCompensation = add(totalPotentialCompensation,COMPENSATION);
        if (scheduledAPIcalls[_insuredItem]!=true) 
            scheduleAPIcall(_insuredItem);
    }
    function scheduleAPIcall(string _insuredItem) private whenNotPaused {
        if (scheduledAPIcalls[_insuredItem]!=true) {
            scheduledAPIcalls[_insuredItem]=true;
            if (oraclize_getPrice("URL") > address(this).balance) {
                emit LogNewOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
            } else {
                string memory queryString = usingOraclize.strConcat('json(https://train-punctuality-index-api.herokuapp.com/indexes?id=', _insuredItem, "", "", "");
                queryString = usingOraclize.strConcat(queryString,' ).0.value', "", "", "");
                emit LogNewOraclizeQuery("Oraclize query was sent, standing by for the answer..");
                bytes32 queryId = oraclize_query(expirationDateMap[_insuredItem], "URL", queryString);
                oraclizeQueriesMap[queryId]=_insuredItem;
              }
        }
    }
    function __callback(bytes32 queryId, string result) public {
        require(msg.sender == oraclize_cbAddress());
        string memory insuredItem = oraclizeQueriesMap[queryId];
        uint actualPunctuality = parseInt(result);
        for (uint k=0; k<insuredItemPoliciesMap[insuredItem].length; k++) {
            uint policyID = insuredItemPoliciesMap[insuredItem][k];
            policiesArray[policyID].conditionChecked = true;
            if (MIN_PUNCTUALITY>actualPunctuality) {
                policiesArray[policyID].entitledToCompensation = true;
                payoutPolicy(policyID);
            }
        }
        emit LogAPIUpdated(usingOraclize.strConcat("Oraclize query response received: ", result, "", "", ""));
    }
    function payoutPolicy(uint _policyID) private {
        require(policiesArray[_policyID].conditionChecked == true);
        require(policiesArray[_policyID].entitledToCompensation == true);
        require(policiesArray[_policyID].paid == false);
        policiesArray[_policyID].paid = true;
        policiesArray[_policyID].owner.transfer(COMPENSATION);
        totalPotentialCompensation = sub(totalPotentialCompensation,COMPENSATION);
    }
}