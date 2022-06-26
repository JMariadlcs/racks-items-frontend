import { ethers } from 'ethers'
import { useEffect, useState } from 'react'
import axios from 'axios'
import Web3Modal from 'web3modal'
import Sidebar from "./components/Sidebar"
import { itemList } from '../itemList'
import { useRouter } from 'next/router'

import {
  commerceAddress,
  tokenAddress
} from '../config'

import RacksItemsv3 from '../build/contracts/RacksItemsv3.json'
import RacksToken from '../build/contracts/RacksToken.json'
import Link from 'next/link'

export default function Opencase({user, userConnected}) {
  const [pickItem, setItem] = useState(0);
  const [opening, setOpening] = useState(false)
  const [items, setItems] = useState([])
  const [fetchedData, setFetchedData] = useState({rarity:0, supply:0})
  const [casePrice, setCasePrice] = useState(0)
  const [vipState, setVipState]=useState(false)
  const [loadingState, setLoadingState] = useState("not-loaded")
  const [processing, setProcessing] = useState(false)
  const [showItemData, setShowItemData] = useState(false);

  useEffect(() => {
    loadVipState()
    if (window.ethereum) {
      window.ethereum.on("accountsChanged", (accounts) => {
      
        setVipState(false)
        loadVipState()
    
    })}
  

  },   [])
  async function loadVipState(){
    
    const web3Modal = new Web3Modal()
    const connection = await web3Modal.connect()
    const provider = new ethers.providers.Web3Provider(connection)
    const signer = provider.getSigner()
    const account = await signer.getAddress()
    const contract = new ethers.Contract(commerceAddress,RacksItemsv3.abi, signer)
    const data = await contract.getUserTicket(account.toString());
    const casePrice = await contract.casePrice()
    const itemsData = await contract.caseLiquidity()

    const items = await Promise.all(itemsData
      
      .map(async i => {
      
       const item= i.toNumber()

      return item
    }))
    setItems(items)
    
    setCasePrice(casePrice.toNumber())
    const {0: durationLeft, 1: triesLeft, 3:ownerOrSpender, 4:ticketPrice} = data;
 
    console.log(items)
    if(data[2].toNumber()==1 || data[2].toNumber()==2){
      setVipState(true)
    }
    setLoadingState("loaded")
    
  }

  async function fetchItemData(tokenId){
    const web3Modal = new Web3Modal()
    const connection = await web3Modal.connect()
    const provider = new ethers.providers.Web3Provider(connection)
    const signer = provider.getSigner()
    const marketContract = new ethers.Contract(commerceAddress,RacksItemsv3.abi, signer)

    const totalSupply = await marketContract.totalSupply();
    const supply = await marketContract.supplyOfItem(pickItem);
    const rarity = totalSupply.toNumber()/supply.toNumber()

    setFetchedData({rarity,supply: supply.toNumber()})
   


  }
  function renderItemData(item){
    
    fetchItemData(item);
    setShowItemData(true)

  }
  async function openCase() {
    setProcessing(true)
    const web3Modal = new Web3Modal()
    const connection = await web3Modal.connect()
    const provider = new ethers.providers.Web3Provider(connection)
    const signer = provider.getSigner()
    const account = await signer.getAddress()
    const Tokencontract = new ethers.Contract(tokenAddress,RacksToken.abi, signer)
    const contract = new ethers.Contract(commerceAddress,RacksItemsv3.abi, signer)
    const approval = await Tokencontract.approve(commerceAddress , casePrice.toString())
    await approval.wait()
    const transaction = await contract.openCase()

    await transaction.wait()
    let gotItem
    contract.on("CaseOpened", (user, casePrice, item) => {
      gotItem = item.toNumber();
      setItem(gotItem)
      console.log(pickItem)
      setProcessing(false)
      renderItemData(gotItem)
      
     

  }
  
  
  );
  


  }

  if(loadingState!=='loaded')
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
  
  return (
  
    <div className='absolute w-full flex flex-col  bg-gradient-to-r from-soft '>
        <div className='flex'>
        <Sidebar/>
        <div class="mainscreen">
          
           { vipState==true ?(
             <div className='flex flex-col justify-center items-center'>
             <h1 className='font-bold mt-36 mb-24 text-3xl flex  text-secondary'> {casePrice} RKS </h1>
           
           <button  onClick={()=>openCase()} className='go '>ABRIR CAJA</button>
           <div className=" p-4 rounded border border-secondary mt-8 grid grid-cols-1 mx-auto my-auto md:grid-cols-3 sm:grid-cols-2 lg:grid-cols-4 gap-4 pt-4">
          {
            items
              .map((item, i) => (
            
              <div className='border  border-main overflow-hidden rounded flex-col items-center bg-main/70' >
                     
                     <div className={`absolute rounded w-2 h-8 bg-secondary ${itemList[item].ticker}`}></div>
                    
                      <img src={itemList[item].imageSrc}  className="w-full   my-8 h-16"/>
                      
                      
                     <img src="/racksLogoDos.png" height="20" width="50" className='mb-4'/> 

                      
              </div>
     
            ))
          }
         
          </div>
           </div>
              

            ):(
              <div className='flex flex-col justify-center items-center'>
                <h1 className='font-bold mt-36 mb-24 text-3xl flex  text-secondary'> <svg className="mr-4" xmlns="http://www.w3.org/2000/svg" width="32" height="32" fill="currentColor" class="bi bi-lock-fill" viewBox="0 0 16 16">
  <path d="M8 1a2 2 0 0 1 2 2v4H6V3a2 2 0 0 1 2-2zm3 6V3a3 3 0 0 0-6 0v4a2 2 0 0 0-2 2v5a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2z"/>
</svg>No tienes permisos </h1>
              <Link href="/tickets">
              <button className='go '>Mercado de tickets</button>
                </Link>
              </div>
            )
          }
           {
             showItemData && (
              <div className=' w-full flex flex-col justify-center items-center fixed  '> 
                           
                    
                    
                    <div class="mainscreen  ">
                      
              
                  <div class="card">
                   
                    <div class="leftside">
                      <img
                        src={itemList[pickItem].imageSrc}
                        className="product my-8"
                      
                      />
                    </div>
                    <div class="rightside">
                      <div className='flex justify-between'><h1 className=' text-main text-xl font-semibold'>{itemList[pickItem].name}</h1><button onClick={()=>setShowItemData(false)}><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-x-lg" viewBox="0 0 16 16">
                              <path d="M2.146 2.854a.5.5 0 1 1 .708-.708L8 7.293l5.146-5.147a.5.5 0 0 1 .708.708L8.707 8l5.147 5.146a.5.5 0 0 1-.708.708L8 8.707l-5.146 5.147a.5.5 0 0 1-.708-.708L7.293 8 2.146 2.854Z"/>
                            </svg></button></div>
                            <p className='text-soft '>Categoría:<label className={`${itemList[pickItem].textColor} m-2 font-semibold`} >{itemList[pickItem].rarity}  </label></p>
                     <p className='text-soft'>Probabilidad:<label className="text-main ml-2 font-semibold" >{(fetchedData.rarity).toFixed(2)}% </label></p>
                     <p className='text-soft'>En circulación:<label className="text-main ml-2 font-semibold" >{fetchedData.supply} </label></p>
    
                    </div>
                  </div>
                </div>
                    </div>
                    
                    )
          }
                  
          
        </div>
      </div>
       
    </div>
  )
}



