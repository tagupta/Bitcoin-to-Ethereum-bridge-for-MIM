// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";

interface AddressProvider{
   function admin() external view returns(address);
}

interface CurvePool{
    function A() external view returns(uint256);
    function future_A() external view returns(uint256);
    function fee() external view returns(uint256);
    function admin_fee() external view returns(uint256);
    function future_fee() external view returns(uint256);
    function future_admin_fee() external view returns(uint256);
    function future_owner() external view returns(address);
    function initial_A() external view returns(uint256);
    function initial_A_time() external view returns(uint256);
    function future_A_time() external view returns(uint256);
    function coins(uint256 i) external view returns(address);
    function underlying_coins(uint256 i) external view returns(address);
    function balances(uint256 i) external view returns(uint256);
    function  get_virtual_price() external view returns(uint256);       
    
}

interface CurvePoolV1{
    function coins(int128 arg0) external view returns(address);
    function underlying_coins(int128 i) external view returns(address);
    function balances(int128 arg0) external view returns(uint256);

}

interface LiquidityGauge{
    function lp_token() external view returns(address);
}

contract Stub_registry {
    int128 constant MAX_COINS = 8;

    struct PoolArray{
        uint256 location;
        uint256 decimals;
        uint256 underlying_decimals;
        bytes32 rate_info;
        address base_pool;
        address[MAX_COINS] coins ;                         
        address[MAX_COINS] ul_coins;
        uint256 n_coins;
        bool has_initial_A;
        bool is_v1;
        string name;
        uint256 asset_type;
    }

    AddressProvider public address_provider;
    mapping(address => PoolArray)pool_data;
    mapping(address => address) public get_lp_token; //pool => lp_token
    mapping(address => address) public get_pool_from_lp_token; //lp token -> pool
    address [65536] public pool_list;  //master list of pools
    uint256 public pool_count; //actual length of pool_list
    uint256 public last_updated;
    mapping(address => address[10])liquidity_gauges;


    function initialize(address _address_provider)public{
      address_provider = AddressProvider(_address_provider);
    }

    function add_pool(address _pool, 
                      uint256 _n_coins, 
                      address _lp_token, 
                      bytes32 _rate_info, 
                      uint256 _decimals, 
                      uint256 _underlying_decimals,
                      bool _has_initial_A, 
                      bool _is_v1,
                      string calldata _name)external{
        _add_pool( msg.sender,_pool,_n_coins,_lp_token,_rate_info,_has_initial_A,_is_v1,_name);
        address [MAX_COINS] memory coins = _get_new_pool_coins(_pool, _n_coins, false, _is_v1);  
        uint256 decimals = _decimals;
        if(decimals == 0){
            decimals = _get_new_pool_decimals(coins, _n_coins);
        } 
        pool_data[_pool].decimals = decimals; 
        pool_data[_pool].underlying_decimals = _underlying_decimals;               
    }

    function _add_pool(address _sender, 
                       address _pool, 
                       uint256 _n_coins,
                       address _lp_token, 
                       bytes32 _rate_info,
                       bool _has_initial_A,
                       bool _is_v1,
                       string memory _name)internal{

        require(address_provider.admin() == _sender,'Stub_registry: only admin can add');
        require(_lp_token != address(0),'Stub_registry: LP token address can not be 0');
        require(pool_data[_pool].coins[0] == address(0),'Stub_registry: pools already exist');
        require(get_pool_from_lp_token[_lp_token] == address(0),'Stub_registry: pools exist for given LP token');

        //add pool to pool_list
        uint256 length = pool_count;
        pool_list[length] = _pool;
        pool_count = length + 1;
        pool_data[_pool].location = length;
        pool_data[_pool].rate_info = _rate_info;
        pool_data[_pool].has_initial_A = _has_initial_A;
        pool_data[_pool].is_v1 = _is_v1;
        pool_data[_pool].n_coins = _n_coins;
        pool_data[_pool].name = _name;

        // update public mappings
        get_pool_from_lp_token[_lp_token] = _pool;
        get_lp_token[_pool] = _lp_token;
        last_updated = block.timestamp;

    }

    function _get_new_pool_coins(address _pool, 
                                 uint256 _n_coins,
                                 bool _is_underlying, 
                                 bool _is_v1) internal returns(address [MAX_COINS] memory){
      address [MAX_COINS] memory coin_list;
      address coin;

      for(uint256 i = 0 ; i < uint128(MAX_COINS) ; i++){
          if(i == _n_coins) break;
          if(_is_underlying){
              if(_is_v1){
                  coin = CurvePoolV1(_pool).underlying_coins(int128(uint128(i)));
              }
              else{
                  coin = CurvePool(_pool).underlying_coins(i);
              }
               pool_data[_pool].ul_coins[i] = coin;
          }
          else{
              if(_is_v1){
                  coin = CurvePoolV1(_pool).coins(int128(uint128(i)));
              }
              else{
                  coin = CurvePool(_pool).coins(i);
              }
               pool_data[_pool].coins[i] = coin;
          }
          coin_list[i] = coin;
      }
      return coin_list;
    }

    function _get_new_pool_decimals(address[MAX_COINS] memory _coins, uint256 _n_coins)internal view returns(uint256){
      uint256 value = 0;
      uint256 packed = 0;

      for(uint i = 0 ; i < uint128(MAX_COINS) ; i++){
           if(i == _n_coins) break;
           address coin = _coins[i];
           if (coin == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE){
                value = 18; 
           }
           else{
                value = ERC20Detailed(coin).decimals();
                require(value < 256,'Stub_registry: decimal overflow');
           }

            packed += value; 
      }    

      return packed;
    }

    function set_liquidity_gauges(address _pool, address[10] calldata _liquidity_gauges) external{
        require(msg.sender == address_provider.admin(),'Stub_registry: only admin can set gauge');
        address _lp_token = get_lp_token[_pool];

        for(uint i = 0 ; i < 10 ; i++){
            address _gauge = _liquidity_gauges[i];
            if(_gauge != address(0)){
                  require (LiquidityGauge(_gauge).lp_token() == _lp_token,'Stub_registry: wrong token');
                  liquidity_gauges[_pool][i] = _gauge;
            }
            else if(liquidity_gauges[_pool][i] != address(0)){
                liquidity_gauges[_pool][i] = address(0);
            }
            else{
                break;
            }
        }
        last_updated = block.timestamp;
    }

    function get_gauges(address _pool) external view returns(address[10] memory){
       address[10] memory __liquidity_gauges;
       for(uint i = 0 ; i < 10 ; i++){
           address gauge = liquidity_gauges[_pool][i];
           if(gauge == address(0)) break;
           __liquidity_gauges[i] = gauge;
       }
       return __liquidity_gauges;
    }
}