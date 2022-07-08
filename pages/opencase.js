import { ethers } from 'ethers'
import { useEffect, useState } from 'react'
import axios from 'axios'
import Web3Modal from 'web3modal'
import Sidebar from "./components/Sidebar"
import { itemList } from '../itemList'
import { useRouter } from 'next/router'
import react from 'react'
import RacksItemsv3 from '../build/contracts/RacksItemsv3.json'
import RacksToken from '../build/contracts/RacksToken.json'
import Link from 'next/link'

import {
  commerceAddress,
  tokenAddress
} from '../config'

export default function Opencase({user, userConnected}) {
  const [marketContract, setMarketContract] = useState()
  const [tokenContract, setTokenContract] = useState()
  const [userAddress, setUserAddress] = useState("")
  const [userBalance, setUserBalance]= useState(0)
  const [allowance , setAllowance] = useState(0)
  const [processingPhase, setProcessingPhase] = useState("")
  const [pickItem, setItem] = useState(0);
  const [items, setItems] = useState([])
  const [fetchedData, setFetchedData] = useState({rarity:0, supply:0 , marketPrice:0})
  const [casePrice, setCasePrice] = useState(0)
  const [vipState, setVipState]=useState(false)
  const [loadingState, setLoadingState] = useState("not-loaded")
  const [processing, setProcessing] = useState(false)
  const [showItemData, setShowItemData] = useState(false);

  useEffect(() => {
    if(marketContract){
      marketContract.on("casePriceChanged", async (price) =>{
        let _price = price.toNumber()
        setCasePrice(_price)
      })
    }
    
    loadVipState()
    if (window.ethereum) {
      window.ethereum.on("accountsChanged", (accounts) => {
      
        setVipState(false)
        loadVipState()
    
    })}
  

  },[])


  async function loadVipState(){
    
    const web3Modal = new Web3Modal()
    const connection = await web3Modal.connect()
    const provider = new ethers.providers.Web3Provider(connection)
    const signer = provider.getSigner()
    const account = await signer.getAddress()
    const market = new ethers.Contract(commerceAddress,RacksItemsv3.abi, signer)
    const token = new ethers.Contract(tokenAddress , RacksToken.abi, signer)
    
    setMarketContract(market)
    setTokenContract(token)
    setUserAddress(account)

    const response = await token.balanceOf(account)
    const response2 = await token.allowance(account, commerceAddress)
    const balance = response.toNumber()
    const approved = response2.toNumber()
    setUserBalance(balance)
    setAllowance(approved)

    const data = await market.getUserTicket(account.toString());
    const casePrice = await market.getCasePrice()
    const itemsData = await market.caseLiquidity()
    const items = await Promise.all(itemsData
      
      .map(async i => {
        const item= i.toNumber()
        
        return item
      }))
      setItems(items)
      setCasePrice(casePrice.toNumber())

    const {0: durationLeft, 1: triesLeft, 3:ownerOrSpender, 4:ticketPrice} = data;
    if(data[2].toNumber()==1 || data[2].toNumber()==2){
      setVipState(true)
    }
    setLoadingState("loaded")
    
  }

  async function fetchItemData(tokenId){
   
    const totalSupply = await marketContract.getMaxTotalSupply();
    const supply = await marketContract.supplyOfItem(tokenId);
    const rarity = totalSupply.toNumber()/supply.toNumber()
    const prices = await marketContract.getItemsOnSale()
    let totalItems=0;
    let totalPrice=0;
    const items = await Promise.all(prices
      .filter(item=> item.tokenId.toNumber()== tokenId)
      .map(async i => {
        const itemPrice = i.price.toNumber()
        totalPrice += itemPrice
        totalItems +=1
    }))
    const marketPrice = totalPrice/totalItems
    setFetchedData({rarity,supply: supply.toNumber(), marketPrice})

  }


  async function renderItemData(item){
    
    await fetchItemData(item);
    setShowItemData(true)

  }



 
  async function openCase() {
 
    
    if(userBalance<casePrice && allowance<casePrice){
      alert("Fondos insuficientes")
    }else{
      try{
        setProcessing(true)

        if(allowance<casePrice){
        setProcessingPhase("Aprovando...")
        const approval = await tokenContract.approve(commerceAddress , casePrice.toString())
        await approval.wait()
        }
      
        setProcessingPhase("Conectando con el oráculo...")
        const transaction = await marketContract.openCase()
        setProcessingPhase("Abriendo caja...")
        await transaction.wait()
        let gotItem

        marketContract.on("CaseOpened", async (user, casePrice, item) =>  {
          gotItem = item.toNumber();
          setItem(gotItem)
          setProcessing(false)
          await renderItemData(gotItem)
          setProcessingPhase("")

        });
  
    }
    catch{
      setProcessing(false)
      setProcessingPhase("")
      }
    }
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
          
           {(vipState==true && processing==false)?(
              <div className='flex flex-col justify-center items-center'>
              <img width = {150} heigth={150} className="my-12" src="/case.png"/>
           
              <button  onClick={()=>openCase()} className='go '>{casePrice} RKS</button>
              <div className=" p-4 rounded border border-secondary mt-8 grid grid-cols-2 mx-auto my-auto md:grid-cols-4 lg:grid-cols-6 gap-4 pt-4">
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
              

          ):(vipState==false)?(
              <div className='flex flex-col justify-center items-center'>
                <h1 className='font-bold mt-36 mb-24 text-3xl flex  text-secondary'> 
                  <svg className="mr-4" xmlns="http://www.w3.org/2000/svg" width="32" height="32" fill="currentColor" class="bi bi-lock-fill" viewBox="0 0 16 16">
                    <path d="M8 1a2 2 0 0 1 2 2v4H6V3a2 2 0 0 1 2-2zm3 6V3a3 3 0 0 0-6 0v4a2 2 0 0 0-2 2v5a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2z"/>
                  </svg> No tienes permisos 
                </h1>
              <Link href="/tickets">
              <button className='go '>Mercado de tickets</button>
                </Link>
              </div>
            ):(
              <div className='flex flex-col  justify-center items-center'>
                {
                  (processingPhase=="Aprovando..." || processingPhase=="Conectando con el oráculo..." || processingPhase=="Abriendo caja..." )&&(
                    <div className='bg-main/70  flex flex-col items-center py-16 px-8 mt-36 border-main border rounded'>
                      <h1 className=' font-bold text-secondary text-3xl'>{processingPhase}</h1>
                      <p className='text-secondary mb-16'>Dependiendo de la demanda de la red puede tardar más de lo esperado.</p>
                          <div class="circle-loader mb-8">
                            <div></div>
                            <div></div>
                            <div></div>
                            <div></div>
                            <div></div>
                            <div></div>
                            <div></div>
                            <div></div>
                          </div>
                     
                    </div>
                  )
                }
              </div>
            )
          }
           {
             showItemData && (
              <div className=' w-full flex flex-col justify-center items-center fixed  '>   
                <div class="mainscreen  ">
                  <div class="card">
                    <div class="leftside">
                      <img src={itemList[pickItem].imageSrc} className="product my-8"/>
                    </div>
                    <div class="rightside">
                      <div className='flex justify-between'>
                        <h1 className=' text-main text-xl font-semibold'>{itemList[pickItem].name}</h1>
                        <button onClick={()=>{setShowItemData(false) ;setProcessingPhase("")}}>
                          <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-x-lg" viewBox="0 0 16 16">
                              <path d="M2.146 2.854a.5.5 0 1 1 .708-.708L8 7.293l5.146-5.147a.5.5 0 0 1 .708.708L8.707 8l5.147 5.146a.5.5 0 0 1-.708.708L8 8.707l-5.146 5.147a.5.5 0 0 1-.708-.708L7.293 8 2.146 2.854Z"/>
                          </svg>
                        </button>
                      </div>
                      <p className='text-soft '>Categoría:<label className={`${itemList[pickItem].textColor} m-2 font-semibold`} >{itemList[pickItem].rarity}  </label></p>
                      <p className='text-soft'>Probabilidad:<label className="text-main ml-2 font-semibold" >{(100/fetchedData.rarity).toFixed(2)}% </label></p>
                      <p className='text-soft'>En circulación:<label className="text-main ml-2 font-semibold" >{fetchedData.supply} </label></p>
                      {
                         fetchedData.marketPrice>0?(
                           <p className='text-soft'>Precio de mercado: <label className="text-main ml-2 font-semibold">{fetchedData.marketPrice.toFixed(2)} RKS</label></p>

                         ):(
                           <p className='text-soft'>Precio de mercado: <label className="text-main ml-2 font-semibold">No disponible</label></p>

                         )
                        }  
                      <div onClick={()=>{setShowItemData(false); openCase()}} className="button cursor-pointer flex justify-center bg-red hover:bg-red/40">Abrir otra ({casePrice} RKS) </div>
                      <Link href="/inventory">
                        <div className="button cursor-pointer flex justify-center bg-orange hover:bg-orange/40">Inventario</div>
                      </Link>
                    
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



