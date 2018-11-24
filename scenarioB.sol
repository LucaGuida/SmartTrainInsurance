pragma solidity 0.4.24;
import "github.com/oraclize/ethereum-api/oraclizeAPI.sol";
import "./Ownable.sol";
import "./Pausable.sol";
import "./SafeMath.sol";
contract SmartTrainInsurance is Ownable, Pausable, usingOraclize {
    struct InsurancePolicy {
    uint      id;
      address   owner;
      string    insuredItem;
      bool      entitledToCompensation;
      bool      conditionChecked;
      bool      paid;
    }
	address public owner = 0x0000000000000000000000000000000000000000;
	uint public constant PREMIUM = 0;
	PREMIUM = 20000000000000000;
	uint public constant COMPENSATION = 0;
	COMPENSATION = 100000000000000000;
	uint public constant MIN_PUNCTUALITY = 0;
	MIN_PUNCTUALITY = 90;
	uint public totalPotentialCompensation = 0;
	totalPotentialCompensation = 0;
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
    function() public payable { 
        require(msg.data.length == 0); 
        emit LogDepositReceived(msg.sender); 
    }
    constructor() public {
        owner = msg.sender;
        expirationDateMap["SEPT2018"] = 1538388000;
        expirationDateMap["AUG2018"] = 1535796000;
    }
    function increaseContractBalance() public payable onlyOwner {
        if (msg.value == 0) return;
        emit LogDepositReceived(msg.sender); 
    }
    function decreaseContractBalance(uint amount) public onlyOwner {
        if (SafeMath.sub(address(this).balance,amount)<totalPotentialCompensation) return;
        owner.transfer(amount);
    }
    function registerNewPolicy(string _insuredItem) public payable whenNotPaused {
        if (msg.value != PREMIUM) return; 
        if (SafeMath.add(address(this).balance,msg.value)<SafeMath.add(totalPotentialCompensation,COMPENSATION)) return; 
        InsurancePolicy policy;
        policy.id = policiesArray.length;
        policy.owner = msg.sender;
        policy.insuredItem = _insuredItem;
        policy.conditionChecked = false;
        policy.entitledToCompensation = false;
        policy.paid = false;
        policiesArray.push(policy);
        insuredItemPoliciesMap[policy.insuredItem].push(policy.id);
        totalPotentialCompensation = SafeMath.add(totalPotentialCompensation,COMPENSATION);
        if (scheduledAPIcalls[_insuredItem]!=true) 
            scheduleAPIcall(_insuredItem);
    }
    function scheduleAPIcall(string _insuredItem) private whenNotPaused {
        if (scheduledAPIcalls[_insuredItem]!=true) {
            scheduledAPIcalls[_insuredItem]=true;
            if (oraclize_getPrice("URL") > address(this).balance) {
                emit LogNewOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
            } else {
                emit LogNewOraclizeQuery("Oraclize query was sent, standing by for the answer..");
        		bytes32 queryId = oraclize_query(expirationDateMap[_insuredItem], "URL", usingOraclize.parseInt(usingOraclize.parseInt("json(https://train-punctuality-index-api.herokuapp.com/indexes?id=",_insuredItem,"","",""),").0.value","","",""));
              }
            oraclizeQueriesMap[queryId]=_insuredItem;
        }
    }
    function payoutPolicy(uint _policyID) private {
        require(policiesArray[_policyID].conditionChecked == true);
        require(policiesArray[_policyID].entitledToCompensation == true);
        require(policiesArray[_policyID].paid == false);
        policiesArray[_policyID].paid = true;
        policiesArray[_policyID].owner.transfer(COMPENSATION);
        totalPotentialCompensation = SafeMath.sub(totalPotentialCompensation,COMPENSATION);
    }
    function __callback(bytes32 queryId, string result) public {
        require(msg.sender == oraclize_cbAddress());
		string memory insuredItem = "";
        insuredItem = oraclizeQueriesMap[queryId];
        uint  actualPunctuality = 0;
        actualPunctuality = parseInt(result);
        for (uint k=0; k<insuredItemPoliciesMap[insuredItem].length; k++) {
            uint  policyID = 0;
            policyID = insuredItemPoliciesMap[insuredItem][k];
            policiesArray[policyID].conditionChecked = true;
            if (MIN_PUNCTUALITY>actualPunctuality) {
                policiesArray[policyID].entitledToCompensation = true;
                payoutPolicy(policyID);
            }
        }
        emit LogAPIUpdated(usingOraclize.strConcat("Oraclize query response received: ", result, "", "", ""));
    }
    function getContractBalance() public view  returns(uint) {
        return address(this).balance;
    }
}