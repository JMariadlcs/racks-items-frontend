import { ethers } from 'ethers'
import { useEffect, useState } from 'react'
import axios from 'axios'
import Web3Modal from 'web3modal'
import Sidebar from "./components/Sidebar"
import Image from "next"
import Link from "next/Link"
import {
  commerceAddress
} from '../config'
import {itemList} from "../itemList"
import RacksItemsv3 from '../build/contracts/RacksItemsv3.json'

import { render } from 'react-dom'


export default function Inventory() {
  const [marketPrices,setMarketPrices] = useState([])
  const [inventoryValue, setInventoryValue] = useState(0)
  const [userAddress, setUserAddress] = useState()
  const [marketContract,setMarketContract]= useState()
  const [searchWallet, setSearchWallet] = useState()
  const [showMarketInventory, setShowMarketInventory] = useState(false)
  const [showForm, setShowForm] = useState(false);
  const [processing, setProcessing] = useState(false);
  const [processingPhase, setProcessingPhase] =  useState("")
  const [showItemData, setShowItemData] = useState(false);
  const [showModify, setShowModify] = useState(false)
  const [fetchedData, setFetchedData] = useState({rarity:0, supply:0, marketPrice:0})
  const [showCheckout, setShowCheckOut] = useState(false);
  const [showDelete, setShowDelete] = useState(false)
  const [pickItem, setItem] = useState();
  const [formInput, updateFormInput] = useState({ price: 0})  
  const [items, setItems] = useState([])

  const [loadingState, setLoadingState] = useState('not-loaded')
  useEffect(() => {
    loadItems()
     
    if (window.ethereum) {
      window.ethereum.on("accountsChanged", (accounts) => {
        setProcessing(false)
        setShowCheckOut(false)
        setShowForm(false)
        setShowItemData(false)
        loadItems()
    
    })}
    if(marketContract){
    marketContract.on("itemBought", ( buyer,  seller, marketItemId,  price) => {
      if(seller==userAddress){
        loadMarketInventory()
      }

    })
  }  },[])


  async function exchangeItem(){

    try{
      setProcessing(true)
      setProcessingPhase("Haciendo pedido...")
      const transaction = await marketContract.exchangeItem(pickItem.tokenId)
      setProcessingPhase("Quemando token...")
      await transaction.wait()
      setProcessing(false)
      setShowCheckOut(false)
      setShowForm(false)
      setShowItemData(false)
      loadItems()
      setProcessingPhase("")

    }catch{

      setProcessing(false)
      setProcessingPhase("")

    }

  }


  async function listItem(){

    if(formInput.price<=0){
      alert("Precio no valido")
    }

    else{

      try{

        setProcessing(true)
        setProcessingPhase("Listando item en el mercado...")
        const transaction = await marketContract.listItemOnMarket(pickItem.tokenId, formInput.price.toString())
        await transaction.wait()
        setProcessingPhase("COMPLETADO")
        setProcessing(false)
        setShowCheckOut(false)
        setShowForm(false)
        setShowItemData(false)
        setProcessingPhase("")
        loadItems()

    }catch{

        setProcessing(false)
        setShowCheckOut(false)
        setShowItemData(false)
        loadItems()
        setProcessingPhase("")
      }
    }
  }

  function renderForm(item){
    setItem(item);
    setShowForm(!showForm)
  }

  function renderModifier(item){
    setItem(item)
    setShowModify(!showModify)
  }

  function renderDelete(item){
    setItem(item)
    setShowDelete(!showDelete)
  }

  function renderCheckout(item){
    setItem(item)
    setShowCheckOut(!showCheckout)
  }

  async function modifyItem(item){
    console.log(formInput.price)
    if(formInput.price==0){
      try{
        setProcessing(true)
        setProcessingPhase("Retirando del mercado...")
        const transaction = await marketContract.changeMarketItem(pickItem.marketItemId, "0")
        await transaction.wait()
        setProcessingPhase("COMPLETADO")
        setShowCheckOut(false)
        setProcessing(false)
        setShowForm(false)
        setShowItemData(false)
        loadItems()
        setProcessingPhase("")

      }catch{
       
        setProcessing(false)
        setProcessingPhase("")

      }
    }else{
      try{
        setProcessing(true)
        setProcessingPhase("Modificando precio...")
        const transaction = await marketContract.changeItemPrice(pickItem.marketItemId, formInput.price.toString())
        await transaction.wait()
        setProcessingPhase("COMPLETADO")
        setShowCheckOut(false)
        setProcessing(false)
        setShowForm(false)
        setShowItemData(false)
        loadItems()
        setProcessingPhase("")

      }catch{
       
        setProcessing(false)
        setProcessingPhase("")

      }
    }
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
    setFetchedData({rarity,supply: supply.toNumber() , marketPrice})
  }


  function renderItemData(item){
    setItem(item)
    fetchItemData(item.tokenId);
    setShowItemData(!showItemData)

  }

  async function loadMarketInventory() {

    const web3Modal = new Web3Modal()
    const connection = await web3Modal.connect()
    const provider = new ethers.providers.Web3Provider(connection)
    const signer = provider.getSigner()
    const account = await signer.getAddress()
    const data = await marketContract.getItemsOnSale()
    
    const items = await Promise.all(data
      .filter(item=> item.itemOwner == account)
      .map(async i => {
      
      let price=i.price.toString()
      let item = {
        tokenId: i.tokenId.toNumber(),
        marketItemId: i.marketItemId.toNumber(),
        price
      }
      
      return item
    }))

    if(items.length){
    setShowMarketInventory(true)
    setItems(items)
    setLoadingState('loaded') 
    }
  }
  
  async function loadItems() {
    setLoadingState('not-loaded')
    setMarketPrices([])
    setInventoryValue(0)
    setShowMarketInventory(false)
    const web3Modal = new Web3Modal()
    const connection = await web3Modal.connect()
    const provider = new ethers.providers.Web3Provider(connection)
    const signer = provider.getSigner()
    const account = await signer.getAddress()
    let _inventoryValue = 0
    setUserAddress(account)
    const contract = new ethers.Contract(commerceAddress,RacksItemsv3.abi, signer)
    setMarketContract(contract)
    const prices = await contract.getItemsOnSale()
    const _marketPrices = []

    for(let j=0; j<itemList.length; j++){
      let totalItems=0;
      let totalPrice=0;
      const itemPrices = await Promise.all(prices
        .filter(item=> item.tokenId.toNumber()== j)
        .map(async i => {
          const itemPrice = i.price.toNumber()
          totalPrice += itemPrice
          totalItems +=1
         }))
     _marketPrices[j] = totalPrice/totalItems
    }

    setMarketPrices(_marketPrices)

    const data = await contract.viewItems(account);
    let itemCounter=0;
    let items = []

    await Promise.all(data.map(async i=> {
      let counter = 0;
      let amount =  i.toNumber()
      while(counter<amount){
        let item = {
          tokenId: itemCounter
        }

        if(!isNaN(marketPrices[item.tokenId])){
        _inventoryValue += marketPrices[item.tokenId]
        }
        
        items.push(
            item
        )
        counter++;
      }

      itemCounter++;
        
        
      }))
      
    setInventoryValue(_inventoryValue)
    setItems(items)
    setLoadingState('loaded') 
  
  }
  

  async function loadExternalInventory(account){

    if(!account.length){
      loadItems()

    }else{

    const web3Modal = new Web3Modal()
    const connection = await web3Modal.connect()
    const provider = new ethers.providers.Web3Provider(connection)
    const signer = provider.getSigner()
    const contract = new ethers.Contract(commerceAddress,RacksItemsv3.abi, signer)
    let _inventoryValue = 0

    setLoadingState("not-loaded")
    try{

      setInventoryValue(0)
      const data = await contract.viewItems(account);
      let itemCounter=0;
      let items = []
      await Promise.all(data.map(async i=> {

      let counter = 0;
      let amount =  i.toNumber()

      while(counter<amount){
        let item = {
          tokenId: itemCounter,
        }

        if(!isNaN(marketPrices[item.tokenId])){
          _inventoryValue += marketPrices[item.tokenId]
        }

        items.push(
            item
        )

        counter++;
      }
      itemCounter++;  
    }))
    
    setInventoryValue(_inventoryValue)
    setItems(items)

  }catch{
    setItems([])
    console.log("Not found")
  }
  setLoadingState('loaded') 
  }
}
 
  

  return (
    <div className='flex bg-gradient-to-r from-soft'>
      <Sidebar/>
      <div className='flex flex-col items-center w-full'>
        <div className='flex flex-col rounded mt-16 white-light'>
          <div className='flex flex-col md:flex-row lg:flex-row'>
            <div className='flex m-4 items-center'>
              <div onClick={()=>loadItems()}  className='bg-main w-36 flex justify-center cursor-pointer my-4 items-center h-8  '>Inventario</div>
              <div onClick={()=>loadMarketInventory()}  className='bg-main my-4 w-36 flex justify-center cursor-pointer items-center h-8 '>En venta</div>
            </div>
            <div className='flex p-4 m-4 md:w-72 lg:w-96 '>
              <input onChange={(e)=> {setSearchWallet(e.target.value); loadExternalInventory(e.target.value)}}  type="text" className="w-full px-4 py-2 text-white bg-main outline-none" placeholder='Buscar wallet'  ></input>       
            </div>
           <div className=" w-full md:w-48 lg:w-48 flex flex-row justify-center p-4  items-center "><label className='bg-main' >{inventoryValue.toFixed(2)} RKS</label></div>
          
          </div>
          {(loadingState!=='loaded')&& (
            <div className = "flex w-full justify-center items-center">
            <div className="loader1">
              <span></span>
              <span></span>
              <span></span>
              <span></span>
              <span></span>
              </div>
              </div>

          )}

          {(loadingState === 'loaded' && !items.length) &&(
            <div><h1 className="px-20 py-10 text-3xl">No encontrado</h1></div>
          
          )}
  
          {!showMarketInventory?(
           
           
            <div className=" mt-4 grid  px-4 py-4 grid-cols-1 mx-auto my-auto md:grid-cols-3 sm:grid-cols-2 lg:grid-cols-4 gap-4 pt-4">
              {
                items.map((item, i) =>(
                  
                  <div key={i} className='border  w-56 rounded border-main overflow-hidden  flex-col items-center bg-main/70' >
                    <div className={`absolute rounded w-2 h-8 bg-secondary ${itemList[item.tokenId].ticker}`}></div>
                      <img src={itemList[item.tokenId].imageSrc} onClick={()=>renderItemData(item)} className=" w-full cursor-pointer  my-8 h-48"/>
                        <p className='flex justify-center text-sm font-bold'>{itemList[item.tokenId].name}</p>
                          {
                            (!searchWallet) &&(
                              <div>
                                <button onClick ={()=>renderCheckout(item)} className='cursor-pointer w-full flex gap-2 justify-center items-center  bg-orange font-bold outline-none text-main px-8 mt-4 hover:bg-soft'>Canjear 
                                  <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 16 16">
                                    <path fillRule="evenodd" d="M10.854 8.146a.5.5 0 0 1 0 .708l-3 3a.5.5 0 0 1-.708 0l-1.5-1.5a.5.5 0 0 1 .708-.708L7.5 10.793l2.646-2.647a.5.5 0 0 1 .708 0z"/>
                                    <path d="M8 1a2.5 2.5 0 0 1 2.5 2.5V4h-5v-.5A2.5 2.5 0 0 1 8 1zm3.5 3v-.5a3.5 3.5 0 1 0-7 0V4H1v10a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V4h-3.5zM2 5h12v9a1 1 0 0 1-1 1H3a1 1 0 0 1-1-1V5z"/>
                                  </svg>
                                </button>
                              
                                <button onClick={()=>renderForm(item)} className='w-full mb-4 bg-red font-bold flex justify-center items-center gap-2 outline-none text-main px-8 mt-4 hover:bg-soft'>Vender 
                                  <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor"  viewBox="0 0 16 16">
                                    <path d="M5.5 9.511c.076.954.83 1.697 2.182 1.785V12h.6v-.709c1.4-.098 2.218-.846 2.218-1.932 0-.987-.626-1.496-1.745-1.76l-.473-.112V5.57c.6.068.982.396 1.074.85h1.052c-.076-.919-.864-1.638-2.126-1.716V4h-.6v.719c-1.195.117-2.01.836-2.01 1.853 0 .9.606 1.472 1.613 1.707l.397.098v2.034c-.615-.093-1.022-.43-1.114-.9H5.5zm2.177-2.166c-.59-.137-.91-.416-.91-.836 0-.47.345-.822.915-.925v1.76h-.005zm.692 1.193c.717.166 1.048.435 1.048.91 0 .542-.412.914-1.135.982V8.518l.087.02z"/>
                                    <path d="M8 15A7 7 0 1 1 8 1a7 7 0 0 1 0 14zm0 1A8 8 0 1 0 8 0a8 8 0 0 0 0 16z"/>
                                    <path d="M8 13.5a5.5 5.5 0 1 1 0-11 5.5 5.5 0 0 1 0 11zm0 .5A6 6 0 1 0 8 2a6 6 0 0 0 0 12z"/>
                                  </svg>
                                </button>
                              </div>
                            )
                          }
                           <img src="/racksLogoDos.png" height="20" width="50" className='mb-4'/> 
                  </div>
              ))}
            </div>):
              (
                
                <div className=" mt-4 grid  px-4 py-4 grid-cols-1 mx-auto my-auto md:grid-cols-3 sm:grid-cols-2 lg:grid-cols-4 gap-4 pt-4">
                  {
                    items.map((item, i) =>(
                      <div key={i} className='border  w-56 rounded border-main overflow-hidden  flex-col items-center bg-main/70' >
                        <div className={`absolute rounded w-2 h-8 bg-secondary ${itemList[item.tokenId].ticker}`}></div>
                          <img src={itemList[item.tokenId].imageSrc} onClick={()=>renderItemData(item)} className=" w-full cursor-pointer  my-8 h-48"/>
                          <p className='flex justify-center text-sm font-bold'>{itemList[item.tokenId].name}</p>
                          <p className="text-red flex justify-center font-semibold" >{item.price} RKS (EN VENTA)</p>
                          <button onClick={()=>renderModifier(item)} className='px-4 py-2 bg-soft w-1/2'>Modificar</button>
                          <button onClick={()=>renderDelete(item)} className='px-4 py-2 bg-main w-1/2'>Retirar</button>
                        <img src="/racksLogoDos.png" height="20" width="50" className='mb-4 mt-4'/> 
                      </div> 
                   ))
                  }
                </div>
              )
          }
        </div>
      </div>
      {showModify && (
        <div className=' w-full flex flex-col justify-center items-center fixed'> 
        <div className='flex '>
          <div className='flex flex-col h-screen w-full sticky top-0'>
            <div class="mainscreen  ">
              <div class="card">
                <div class="leftside">
                  <img src={itemList[pickItem.tokenId].imageSrc} className="product m-8"/>
                </div>
                  <div class="rightside">
                    <form action="">
                      <div className='flex justify-between'>
                        <h1 className='font-semibold'>{itemList[pickItem.tokenId].name}</h1>
                        <button onClick={()=>setShowModify(false)}>
                          <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-x-lg" viewBox="0 0 16 16">
                            <path d="M2.146 2.854a.5.5 0 1 1 .708-.708L8 7.293l5.146-5.147a.5.5 0 0 1 .708.708L8.707 8l5.147 5.146a.5.5 0 0 1-.708.708L8 8.707l-5.146 5.147a.5.5 0 0 1-.708-.708L7.293 8 2.146 2.854Z"/>
                          </svg>
                        </button>
                      </div>
                    <h2 className='text-soft'>Modelo exclusivo de Racks Items</h2>
                    <p>Nuevo precio (RKS)</p>
                    <input onChange={(e)=>updateFormInput({price: e.target.value}) } type="number" class="inputbox" name="name"  />
                    <div class="expcvv"> </div>
                    {
                      processing ? (
                        <div >
                          <div  className="button flex justify-center bg-red-40 ">
                           <div class="vender">
                            <div></div>
                            <div></div>
                            <div></div>
                            </div>
                          </div>
                          <div className='text-soft flex flex-col w-full items-center pt-4'> {processingPhase} </div>
                        </div>
                      ):(
                      <div onClick={()=>modifyItem(pickItem)} className="button cursor-pointer flex justify-center bg-orange hover:bg-orange/40">Cambiar precio</div>)
                    }

                    </form>
                  </div>
              </div>
            </div>
          </div>  
        </div>
      </div>
      )
    }
    {
      showDelete &&(
        
        <div className=' w-full flex flex-col justify-center items-center fixed'> 
          <div className='flex '>
            <div className='flex flex-col h-screen w-full sticky top-0'>
              <div class="mainscreen  ">
                <div class="card">
                  <div class="leftside">
                    <img src={itemList[pickItem.tokenId].imageSrc} className="product m-8"/>
                  </div>
                  <div class="rightside">
                    <form action="">
                      <div className='flex justify-between'>
                        <h1 className='font-semibold'>{itemList[pickItem.tokenId].name}</h1>
                        <button onClick={()=>setShowDelete(false)}>
                          <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-x-lg" viewBox="0 0 16 16">
                            <path d="M2.146 2.854a.5.5 0 1 1 .708-.708L8 7.293l5.146-5.147a.5.5 0 0 1 .708.708L8.707 8l5.147 5.146a.5.5 0 0 1-.708.708L8 8.707l-5.146 5.147a.5.5 0 0 1-.708-.708L7.293 8 2.146 2.854Z"/>
                          </svg>
                        </button>
                      </div>
                      <h2 className='text-soft'>Modelo exclusivo de Racks Items</h2>
                      <div class="expcvv"></div>
                        {
                              processing ? (
                                <div >
                                  <div  className="button flex justify-center bg-red-40 ">
                                    <div class="vender">
                                      <div></div>
                                      <div></div>
                                      <div></div>
                                    </div>
                                  </div>
                                  <div className='text-soft flex flex-col w-full items-center pt-4'> {processingPhase} </div>
                                </div>
                              ):(
                              <div onClick={()=>{ updateFormInput(0);modifyItem(pickItem)}} className="button cursor-pointer flex justify-center bg-red hover:bg-red/40">Retirar</div>)
                        }

                    </form>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

      )
    }
    {showForm && (
        <div className=' w-full flex flex-col justify-center items-center fixed'> 
          <div className='flex '>
            <div className='flex flex-col h-screen w-full sticky top-0'>
              <div class="mainscreen  ">
                <div class="card">
                  <div class="leftside">
                    <img src={itemList[pickItem.tokenId].imageSrc} className="product m-8"/>
                  </div>
                  <div class="rightside">
                    <form action="">
                      <div className='flex justify-between'>
                        <h1 className='font-semibold'>{itemList[pickItem.tokenId].name}</h1>
                        <button onClick={()=>{setProcessing(false);setShowCheckOut(false);setShowForm(false) ;setShowItemData(false);}}>
                          <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-x-lg" viewBox="0 0 16 16">
                            <path d="M2.146 2.854a.5.5 0 1 1 .708-.708L8 7.293l5.146-5.147a.5.5 0 0 1 .708.708L8.707 8l5.147 5.146a.5.5 0 0 1-.708.708L8 8.707l-5.146 5.147a.5.5 0 0 1-.708-.708L7.293 8 2.146 2.854Z"/>
                          </svg>
                        </button>
                      </div>
                      <h2 className='text-soft'>Modelo exclusivo de Racks Items</h2>
                      <p>Precio (RKS)</p>
                      <input onChange={(e)=>updateFormInput({price: e.target.value}) } type="number" class="inputbox" name="name" required />
                        <div class="expcvv"> 
                        </div>
                        {
                           processing ? (
                            <div>
                              <div  className="button flex justify-center bg-red-40 "> 
                                <div class="vender">
                                  <div></div>
                                  <div></div>
                                  <div></div>
                                  </div></div>
                              <div className='text-soft flex flex-col w-full items-center pt-4'> {processingPhase} </div>
                            </div>

                           ):(
                           <div onClick={()=>listItem(pickItem)} className="button cursor-pointer flex justify-center bg-red hover:bg-red/40">Vender</div>)
                        }
                    </form>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}
      
      {
        showCheckout && (
          <div className=' w-full flex flex-col justify-center items-center fixed '> 
            <div className='flex '>
              <div class="mainscreen ">
                <div class="card">
                  <div class="leftside">
                    <img src={itemList[pickItem.tokenId].imageSrc} className="product"/>
                  </div>
                  <div class="rightside">
                    <form >
                      <div className='flex justify-between'>
                        <h1 className='font-semibold'>{itemList[pickItem.tokenId].name}</h1>
                        <button onClick={()=>{setProcessing(false);setShowCheckOut(false);setShowForm(false) ;setShowItemData(false);}}>
                          <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-x-lg" viewBox="0 0 16 16">
                            <path d="M2.146 2.854a.5.5 0 1 1 .708-.708L8 7.293l5.146-5.147a.5.5 0 0 1 .708.708L8.707 8l5.147 5.146a.5.5 0 0 1-.708.708L8 8.707l-5.146 5.147a.5.5 0 0 1-.708-.708L7.293 8 2.146 2.854Z"/>
                          </svg>
                        </button>
                      </div>
                    <h2 className='text-soft'>Modelo exclusivo de Racks Items</h2>
                    <p>Nombre</p>
                    <input type="text" class="inputbox" name="name" required />
                    <p>Direccion</p>
                    <input type="text" class="inputbox" name="card_number" id="card_number" required />
                    <div class="expcvv">
                      <p>Atención: Tras hacer el pedido este token será quemado y por lo tanto eliminado de tu inventario permanentemente.</p>
                    </div>
                    {
                      processing ? (
                        <div>
                            <div  className="button flex justify-center bg-orange-40 ">
                              <div class="canjear">
                                <div></div>
                                <div></div>
                                <div></div>
                              </div>
                            </div>
                            <div className='flex flex-col w-full items-center text-soft'>{processingPhase}</div>
                        </div>
                      ):(
                        <div onClick={exchangeItem} className="button cursor-pointer flex justify-center bg-orange hover:bg-orange/40">Hacer pedido</div>
                      )
                    }
                    
                    </form>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )
      }
      {
        showItemData && (
          <div className=' w-full flex flex-col justify-center items-center fixed '> 
            <div class="mainscreen  ">
              <div class="card">  
                <div class="leftside">
                  <img src={itemList[pickItem.tokenId].imageSrc} className="product my-8" />
                </div>
                <div class="rightside">
                  <div className='flex justify-between'>
                    <h1 className=' text-main text-xl font-semibold'>{itemList[pickItem.tokenId].name}</h1>
                    <button onClick={()=>{setProcessing(false);setShowCheckOut(false);setShowForm(false) ;setShowItemData(false);}}>
                      <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-x-lg" viewBox="0 0 16 16">
                        <path d="M2.146 2.854a.5.5 0 1 1 .708-.708L8 7.293l5.146-5.147a.5.5 0 0 1 .708.708L8.707 8l5.147 5.146a.5.5 0 0 1-.708.708L8 8.707l-5.146 5.147a.5.5 0 0 1-.708-.708L7.293 8 2.146 2.854Z"/>
                      </svg>
                    </button>
                  </div>
                  <p className='text-soft '>Categoría:<label className={`${itemList[pickItem.tokenId].textColor} m-2 font-semibold`} >{itemList[pickItem.tokenId].rarity}  </label></p>
                  <p className='text-soft'>Probabilidad:<label className="text-main ml-2 font-semibold" >{(100/fetchedData.rarity).toFixed(2)}% </label></p>
                  <p className='text-soft'>En circulación:<label className="text-main ml-2 font-semibold" >{fetchedData.supply} </label></p>
                  {
                    fetchedData.marketPrice>0?(
                      <p className='text-soft'>Precio de mercado: <label className="text-main ml-2 font-semibold">{fetchedData.marketPrice.toFixed(2)} RKS</label></p>

                    ):(
                      <p className='text-soft'>Precio de mercado: <label className="text-main ml-2 font-semibold">No disponible</label></p>
                    )
                  }
                

                </div>
              </div>
            </div>
          </div> )
      }
  </div>
  )
}