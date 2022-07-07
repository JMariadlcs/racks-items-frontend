import { ethers } from 'ethers'
import { useEffect, useState } from 'react'
import Web3Modal from 'web3modal'
import Sidebar from "./components/Sidebar"
import Link from "next/Link"
import {useRouter}from 'next/router'
import {
  commerceAddress,
  tokenAddress
} from '../config'

import { itemList } from '../itemlist'
import RacksItemsv3 from '../build/contracts/RacksItemsv3.json'
import RacksToken from '../build/contracts/RacksToken.json'


export default function Market({user, userConnected}) {
  const router = useRouter()
  const [userBalance, setUserBalance]= useState(0)
  const [allowance, setAllowance] = useState(0)
  const [processing, setProcessing] = useState(false);
  const [processingPhase, setProcessingPhase] = useState("")
  const [showItemData, setShowItemData] = useState(false);
  const [fetchedData, setFetchedData] = useState({rarity:0, supply:0})
  const [pickItem, setItem] = useState();
  const [items, setItems] = useState([])
  const [loadingState, setLoadingState] = useState('not-loaded')
  useEffect(() => {
    loadItems()
    if (window.ethereum) {
      window.ethereum.on("accountsChanged", (accounts) => {
        loadItems()
    })}
  }, [])

  async function fetchItemData(tokenId){

    loadUserBalance()
    const web3Modal = new Web3Modal()
    const connection = await web3Modal.connect()
    const provider = new ethers.providers.Web3Provider(connection)
    const signer = provider.getSigner()
    const account = await signer.getAddress()
    const marketContract = new ethers.Contract(commerceAddress,RacksItemsv3.abi, signer)
    const totalSupply = await marketContract.getMaxTotalSupply();
    const supply = await marketContract.supplyOfItem(tokenId);
    const rarity = totalSupply.toNumber()/supply.toNumber()

    setFetchedData({rarity,supply: supply.toNumber()})


  }


  function renderItemData(item){
    setItem(item)
    fetchItemData(item.tokenId);
    setShowItemData(!showItemData)

  }


  async function loadUserBalance(){
    const web3Modal = new Web3Modal()
    const connection = await web3Modal.connect()
    const provider = new ethers.providers.Web3Provider(connection)
    const signer = provider.getSigner()
    const account = await signer.getAddress()
    const tokenContract = new ethers.Contract(tokenAddress,RacksToken.abi, signer)
    const response = await tokenContract.balanceOf(account)
    const response2 = await tokenContract.allowance(account, commerceAddress)
    const userBalance = response.toNumber()
    const approved = response2.toNumber()

    setUserBalance(userBalance)
    setAllowance(approved)


  }
  
  async function buyItem(item) {
    if(userBalance<item.price && allowance <item.price){
      alert("Balance insuficiente")
    }else{
      setProcessing(true)
      const web3Modal = new Web3Modal()
      const connection = await web3Modal.connect()
      const provider = new ethers.providers.Web3Provider(connection)
      const signer = provider.getSigner()
      const Tokencontract = new ethers.Contract(tokenAddress,RacksToken.abi, signer)
      const marketContract = new ethers.Contract(commerceAddress,RacksItemsv3.abi, signer)

      try{

        if(allowance<item.price){
          setProcessingPhase("Aprovando token...")
          const approval = await Tokencontract.approve(commerceAddress, item.price.toString())
          await approval.wait()
        }
        
        setProcessingPhase("Realizando pago...")
        const transaction = await marketContract.buyItem(item.marketItemId ,{gasLimit : 3000000})
        await transaction.wait()
        setProcessingPhase("COMPLETADO")
        setProcessing(false)
        setShowItemData(false)
        loadItems()

      }catch{
        setProcessingPhase("")
        setProcessing(false)
      }

      }   
  }

  async function loadItems() {
    loadUserBalance()
    const web3Modal = new Web3Modal()
    const connection = await web3Modal.connect()
    const provider = new ethers.providers.Web3Provider(connection)
    const signer = provider.getSigner()
    const account = await signer.getAddress()
    const contract = new ethers.Contract(commerceAddress,RacksItemsv3.abi, signer)
    const data = await contract.getItemsOnSale()
    const items = await Promise.all(data
      .filter(item=> item.itemOwner != account)
      .map(async i => {
      
      let price=i.price.toString()
      let owner = i.itemOwner

      let item = {
        marketItemId: i.marketItemId.toNumber(),
        price,
        tokenId: i.tokenId.toNumber(),
        owner
      }
      
      return item
    }))
    setItems(items)
    setLoadingState('loaded') 
  }


  if(loadingState!=='loaded'){
    return(
      <div className="flex bg-gradient-to-r from-soft">
        <Sidebar/>
      <div className = "flex w-full justify-center items-center">
        <div className="loader1">
          <span></span>
          <span></span>
          <span></span>
          <span></span>
          <span></span>
          </div>
          </div>
      </div>
    )
  }
  
  else if (loadingState === 'loaded' && !items.length) return (
    <div className='flex bg-gradient-to-r from-soft'>
      <Sidebar/>
      <h1 className="px-20 py-10 text-md">No hay items en venta disponibles para ti.</h1>
    </div>
  )

  return (
    <div className='flex bg-gradient-to-r from-soft'>
        <Sidebar/>
        <div className=" grid grid-cols-1 mx-auto my-auto md:grid-cols-3 sm:grid-cols-2 lg:grid-cols-4 gap-4 pt-4">
              {
                items
                  .map((item, i) => (
                  
                  <div className='border w-56  border-main overflow-hidden rounded flex-col items-center bg-main/70' >

                         <div className={`absolute rounded w-2 h-8 bg-secondary ${itemList[item.tokenId].ticker}`}></div>

                          <img src={itemList[item.tokenId].imageSrc} onClick={()=>renderItemData(item)} className="w-full cursor-pointer  my-8 h-48"/>

                          <p className='flex justify-center text-sm font-bold'>{itemList[item.tokenId].name}</p>

                          <button onClick={()=>buyItem(item)} className='w-full mb-4 bg-secondary font-bold outline-none text-main px-8 mt-4 hover:bg-soft'>{item.price} RKS</button>
                         <img src="/racksLogoDos.png" height="20" width="50" className='mb-4'/> 
                  

                  </div>

                ))
              }
              </div>
              {
              
                showItemData && (
                  <div className=' w-full flex flex-col justify-center items-center fixed'> 
                    <div className='flex '>
                        <div class="mainscreen ">
                          <div class="card">                      
                            <div class="leftside">
                              <img src={itemList[pickItem.tokenId].imageSrc} className="product my-8"/>
                            </div>
                            <div class="rightside">
                              <div className='flex justify-between'>
                                <h1 className=' text-main text-xl font-semibold'>{itemList[pickItem.tokenId].name}</h1>
                                <button onClick={()=>{setProcessing(false);setShowItemData(false);}}>
                                  <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-x-lg" viewBox="0 0 16 16">
                                    <path d="M2.146 2.854a.5.5 0 1 1 .708-.708L8 7.293l5.146-5.147a.5.5 0 0 1 .708.708L8.707 8l5.147 5.146a.5.5 0 0 1-.708.708L8 8.707l-5.146 5.147a.5.5 0 0 1-.708-.708L7.293 8 2.146 2.854Z"/>
                                  </svg>
                                </button>
                              </div>
                              <p className='text-soft'>Categoría:<label className={`ml-2 ${itemList[pickItem.tokenId].textColor} font-semibold`} >{itemList[pickItem.tokenId].rarity} </label></p>
                              <p className='text-soft'>Probabilidad:<label className="text-main ml-2 font-semibold" >{(100/fetchedData.rarity).toFixed(2)}% </label></p>
                              <p className='text-soft'>En circulación:<label className="text-main ml-2 font-semibold" >{fetchedData.supply} </label></p>
                              <p className='text-soft'>Precio: <label className='mr-2'>{pickItem.price}</label>RKS</p>
                              <div class="expcvv">
                            </div>
    
                    {
                           processing ? (
                            <div>
                              <div  className="button flex justify-center bg-pink-40 ">
                                <div class="comprar ">
                                  <div></div>
                                  <div></div>
                                  <div></div>
                                  </div></div>
                                  <div className='text-soft flex flex-col w-full items-center pt-4'> {processingPhase} </div>
                            </div>

                          ): (userBalance<pickItem.price)?
                            (
                              <div className='text-soft font-semibold'>No tienes fondos suficientes</div>
                            ):
                            
                            (
                              <div onClick={()=>buyItem(pickItem)} className="button cursor-pointer flex justify-center bg-pink hover:bg-pink/40">Comprar</div>
                            )
                            }

                  


                            </div>
                          </div>
                       </div>
                    </div>
                </div>
                    )
                  }
          </div>
  )
}