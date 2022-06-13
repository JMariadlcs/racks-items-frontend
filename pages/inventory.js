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
  const [showForm, setShowForm] = useState(false);
  const [processing, setProcessing] = useState(false);
  const [showItemData, setShowItemData] = useState(false);
  const [fetchedData, setFetchedData] = useState({rarity:0, supply:0})
  const [showCheckout, setShowCheckOut] = useState(false);
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
  

  },   [])


  async function exchangeItem(){
    setProcessing(true)
    const web3Modal = new Web3Modal()
    const connection = await web3Modal.connect()
    const provider = new ethers.providers.Web3Provider(connection)
    const signer = provider.getSigner()
    const marketContract = new ethers.Contract(commerceAddress,RacksItemsv3.abi, signer)
    const transaction = await marketContract.exchangeItem(pickItem.tokenId)
    await transaction.wait()
    setProcessing(false)
    setShowCheckOut(false)
    setShowForm(false)
    setShowItemData(false)
    loadItems()


  }
  async function listItem(){
    setProcessing(true)
    const web3Modal = new Web3Modal()
    const connection = await web3Modal.connect()
    const provider = new ethers.providers.Web3Provider(connection)
    const signer = provider.getSigner()
    const marketContract = new ethers.Contract(commerceAddress,RacksItemsv3.abi, signer)
    const transaction = await marketContract.listItemOnMarket(pickItem.tokenId, formInput.price.toString())
    await transaction.wait()
    setProcessing(false)
    setShowCheckOut(false)
    setShowForm(false)
    setShowItemData(false)
    loadItems()



  }
   function renderForm(item){
      
     setItem(item);
      setShowForm(!showForm)
    
  }
  function renderCheckout(item){
    setItem(item)
    setShowCheckOut(!showCheckout)
  }
  async function fetchItemData(tokenId){
    const web3Modal = new Web3Modal()
    const connection = await web3Modal.connect()
    const provider = new ethers.providers.Web3Provider(connection)
    const signer = provider.getSigner()
    const marketContract = new ethers.Contract(commerceAddress,RacksItemsv3.abi, signer)

    const rarity = await marketContract.rarityOfItem(tokenId);
    const supply = await marketContract.supplyOfItem(tokenId);

    setFetchedData({rarity: rarity.toNumber(),supply: supply.toNumber()})
   


  }
  function renderItemData(item){
    setItem(item)
    fetchItemData(item.tokenId);
    setShowItemData(!showItemData)

  }
  
  async function loadItems() {
    const web3Modal = new Web3Modal()
    const connection = await web3Modal.connect()
    const provider = new ethers.providers.Web3Provider(connection)
    const signer = provider.getSigner()
    const account = await signer.getAddress()

    const contract = new ethers.Contract(commerceAddress,RacksItemsv3.abi, signer)
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

        items.push(
            item
        )
        counter++;
      }
       itemCounter++;
        
        
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
    <div className='flex'>
      <Sidebar/>
    <h1 className="px-20 py-10 text-3xl">Tu inventario está vacío</h1></div>
  )
  return (
    <div className='flex bg-gradient-to-r from-soft'>
    <Sidebar/>
   
    <div className=" mt-16 grid white-light rounded px-4 py-4 grid-cols-1 mx-auto my-auto md:grid-cols-3 sm:grid-cols-2 lg:grid-cols-4 gap-4 pt-4">
    {
            items.map((item, i) =>(
              <div key={i} className='border  w-56 rounded border-main overflow-hidden  flex-col items-center bg-main/70' >
                     
                     <div className={`absolute rounded w-2 h-8 bg-secondary ${itemList[item.tokenId].ticker}`}></div>
                     
                      <img src={itemList[item.tokenId].imageSrc} onClick={()=>renderItemData(item)} className=" w-full cursor-pointer  my-8 h-48"/>

                      <p className='flex justify-center text-sm font-bold'>{itemList[item.tokenId].name}</p>
  
                      <button onClick ={()=>renderCheckout(item)} className='cursor-pointer w-full flex gap-2 justify-center items-center  bg-orange font-bold outline-none text-main px-8 mt-4 hover:bg-soft'>Canjear <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 16 16">
                              <path fillRule="evenodd" d="M10.854 8.146a.5.5 0 0 1 0 .708l-3 3a.5.5 0 0 1-.708 0l-1.5-1.5a.5.5 0 0 1 .708-.708L7.5 10.793l2.646-2.647a.5.5 0 0 1 .708 0z"/>
                              <path d="M8 1a2.5 2.5 0 0 1 2.5 2.5V4h-5v-.5A2.5 2.5 0 0 1 8 1zm3.5 3v-.5a3.5 3.5 0 1 0-7 0V4H1v10a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V4h-3.5zM2 5h12v9a1 1 0 0 1-1 1H3a1 1 0 0 1-1-1V5z"/>
                            </svg>
                      </button>
                    
                      <button onClick={()=>renderForm(item)} className='w-full mb-4 bg-red font-bold flex justify-center items-center gap-2 outline-none text-main px-8 mt-4 hover:bg-soft'>Vender <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor"  viewBox="0 0 16 16">
                              <path d="M5.5 9.511c.076.954.83 1.697 2.182 1.785V12h.6v-.709c1.4-.098 2.218-.846 2.218-1.932 0-.987-.626-1.496-1.745-1.76l-.473-.112V5.57c.6.068.982.396 1.074.85h1.052c-.076-.919-.864-1.638-2.126-1.716V4h-.6v.719c-1.195.117-2.01.836-2.01 1.853 0 .9.606 1.472 1.613 1.707l.397.098v2.034c-.615-.093-1.022-.43-1.114-.9H5.5zm2.177-2.166c-.59-.137-.91-.416-.91-.836 0-.47.345-.822.915-.925v1.76h-.005zm.692 1.193c.717.166 1.048.435 1.048.91 0 .542-.412.914-1.135.982V8.518l.087.02z"/>
                              <path d="M8 15A7 7 0 1 1 8 1a7 7 0 0 1 0 14zm0 1A8 8 0 1 0 8 0a8 8 0 0 0 0 16z"/>
                              <path d="M8 13.5a5.5 5.5 0 1 1 0-11 5.5 5.5 0 0 1 0 11zm0 .5A6 6 0 1 0 8 2a6 6 0 0 0 0 12z"/>
                            </svg>
                      </button>
                     <img src="/racksLogoDos.png" height="20" width="50" className='mb-4'/> 

                      
              </div>
            )
            )
          }
    </div>
  
    {showForm && (
        <div className=' w-full flex flex-col justify-center items-center fixed'> 
        <div className='flex '>

<div className='flex flex-col h-screen w-full sticky top-0'>
<div class="mainscreen  ">
  

<div class="card">

<div class="leftside">
  <img
    src={itemList[pickItem.tokenId].imageSrc}
    className="product m-8"
  
  />
</div>
<div class="rightside">
  <form action="">
     
    <div className='flex justify-between'><h1 className='font-semibold'>{itemList[pickItem.tokenId].name}</h1><button onClick={()=>{setProcessing(false);setShowCheckOut(false);setShowForm(false) ;setShowItemData(false);}}><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-x-lg" viewBox="0 0 16 16">
<path d="M2.146 2.854a.5.5 0 1 1 .708-.708L8 7.293l5.146-5.147a.5.5 0 0 1 .708.708L8.707 8l5.147 5.146a.5.5 0 0 1-.708.708L8 8.707l-5.146 5.147a.5.5 0 0 1-.708-.708L7.293 8 2.146 2.854Z"/>
</svg></button></div>
    <h2 className='text-soft'>Modelo exclusivo de Racks Items</h2>
    <p>Precio</p>
    <input onChange={(e)=>updateFormInput({price: e.target.value}) } type="number" class="inputbox" name="name" required />
    

  
<div class="expcvv">


  
</div>
   {
         processing ? (
           <div  className="button flex justify-center bg-red-40 "> <div class="vender"><div></div><div></div><div></div></div></div>
    

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
                  <img
                    src={itemList[pickItem.tokenId].imageSrc}
                    class="product"
                  
                  />
                </div>
                <div class="rightside">
                  <form >
                     
                    <div className='flex justify-between'><h1 className='font-semibold'>{itemList[pickItem.tokenId].name}</h1><button onClick={()=>{setProcessing(false);setShowCheckOut(false);setShowForm(false) ;setShowItemData(false);}}><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-x-lg" viewBox="0 0 16 16">
  <path d="M2.146 2.854a.5.5 0 1 1 .708-.708L8 7.293l5.146-5.147a.5.5 0 0 1 .708.708L8.707 8l5.147 5.146a.5.5 0 0 1-.708.708L8 8.707l-5.146 5.147a.5.5 0 0 1-.708-.708L7.293 8 2.146 2.854Z"/>
</svg></button></div>
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
                        <div  className="button flex justify-center bg-orange-40 "> <div class="canjear"><div></div><div></div><div></div></div>
                      </div>

                      ):(
                      <div onClick={exchangeItem} className="button cursor-pointer flex justify-center bg-orange hover:bg-orange/40">Hacer pedido
                      </div>
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
          <div className=' w-full flex flex-col justify-center items-center fixed  '> 
                       
                
                
                <div class="mainscreen  ">
                  
          
              <div class="card">
               
                <div class="leftside">
                  <img
                    src={itemList[pickItem.tokenId].imageSrc}
                    className="product my-8"
                  
                  />
                </div>
                <div class="rightside">
                  <div className='flex justify-between'><h1 className=' text-main text-xl font-semibold'>{itemList[pickItem.tokenId].name}</h1><button onClick={()=>{setProcessing(false);setShowCheckOut(false);setShowForm(false) ;setShowItemData(false);}}><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-x-lg" viewBox="0 0 16 16">
                          <path d="M2.146 2.854a.5.5 0 1 1 .708-.708L8 7.293l5.146-5.147a.5.5 0 0 1 .708.708L8.707 8l5.147 5.146a.5.5 0 0 1-.708.708L8 8.707l-5.146 5.147a.5.5 0 0 1-.708-.708L7.293 8 2.146 2.854Z"/>
                        </svg></button></div>
                        <p className='text-soft '>Categoría:<label className={`${itemList[pickItem.tokenId].textColor} m-2 font-semibold`} >{itemList[pickItem.tokenId].rarity}  </label></p>
                 <p className='text-soft'>Probabilidad:<label className="text-main ml-2 font-semibold" >{(100/fetchedData.rarity).toFixed(2)}% </label></p>
                 <p className='text-soft'>En circulación:<label className="text-main ml-2 font-semibold" >{fetchedData.supply} </label></p>

                </div>
              </div>
            </div>
                </div>
                
                )
              }
    </div>
   

  )
}