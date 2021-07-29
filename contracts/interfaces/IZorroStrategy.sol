pragma solidity >=0.6.4;

import "./IBEP20.sol";

interface IZorroStrategy is IBEP20 {
    modifier ownerOnly;
    function compound() external;

}