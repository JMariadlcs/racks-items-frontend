import { ethers } from 'ethers'
import { useEffect, useState } from 'react'
import axios from 'axios'
import Web3Modal from 'web3modal'
import Sidebar from "./components/Sidebar"

import {
  commerceAddress
} from '../config'
import {
    tokenAddress 
} from "../config"
import RacksItemsv3 from '../build/contracts/RacksItemsv3.json'
import RacksToken from '../build/contracts/RacksToken.json'

export default function Tickets({user, userConnected}) {
  const [formInput, updateFormInput] = useState({ tries: 0, hours: 0, price : 0})  
  const [processing, setProcessing] = useState(false);
  const [processingPhase, setProcessingPhase] =  useState("")
  const [profilePic , setProfilePic]= useState("")
  const [showForm,setShowForm] = useState(false)
  const [ticketUser, setUser]= useState()
  const [ticket, setTicket] = useState({})
  const [ticketState, setTicketState]= useState({})
  const [items, setItems] = useState([])
  const [loadingState, setLoadingState] = useState('not-loaded')
  useEffect(() => {
    loadItems()
    loadOwned()
    if (window.ethereum) {
      window.ethereum.on("accountsChanged", (accounts) => {
        loadItems()
        loadOwned()
    })}
  }, [])
  
  async function loadOwned(){
    const web3Modal = new Web3Modal()
    const connection = await web3Modal.connect()
    const provider = new ethers.providers.Web3Provider(connection)
    const signer = provider.getSigner()
    const contract = new ethers.Contract(commerceAddress,RacksItemsv3.abi, signer)
    const account = await signer.getAddress()
    const data = await contract.getUserTicket(account)
    const {0: durationLeft, 1: triesLeft, 2:ownerOrSpender, 3:ticketPrice} = data;
    const userTicket = {
     durationLeft: data.durationLeft.toNumber(),
     triesLeft : data.triesLeft.toNumber(),
     ownerOrSpender : data.ownerOrSpender.toNumber(),
     ticketPrice : data.ticketPrice.toNumber()
    }
    
    setUser(account)
    setTicket(userTicket)
    
    
    if(ticket.ownerOrSpender!=0 && ticket.ownerOrSpender!=3){
      const response =await fetch("https://arweave.net/u2pCDNJIPg8-yfI00u5V_kfqpR5c952nqoOLEM2_mXE")
      const data = await response.json()
      const URI = data.image
      setProfilePic(URI)
     
    }
   
    if(ticket.durationLeft==0 ||ticket.triesLeft==0){
      setTicketState({color:"bg-red", message:"Caducado"})
    }else{
      setTicketState({color:"bg-green", message:"Activo"})
    }

  }

  
  async function buyTicket(item){
    if(ticket.ownerOrSpender!=1 && ticket.ownerOrSpender!=3 && ticket.ownerOrSpender!=4){
    const web3Modal = new Web3Modal()
    const connection = await web3Modal.connect()
    const provider = new ethers.providers.Web3Provider(connection)
    const signer = provider.getSigner()
    const contract = new ethers.Contract(tokenAddress,RacksToken.abi, signer)
    const contract2 = new ethers.Contract(commerceAddress,RacksItemsv3.abi, signer)
    
  
    const transaction = await contract.approve(commerceAddress,item.price.toString())
    await transaction.wait()

    const transaction2 = await contract2.buyTicket(item.owner.toString());
    await transaction2.wait()
    }else{
      alert("Un ususario VIP no puede copmprar otros tickets")
    }
  }

  function renderListTicket(){
    setShowForm(true)
  }
  async function listTicket(){
    
    if(
      formInput.price>0
      && formInput.hours <=168
      && formInput.tries >0

    ){
      try{
        setProcessing(true)
        setProcessingPhase("Listando en el mercado...")
        const web3Modal = new Web3Modal()
        const connection = await web3Modal.connect()
        const provider = new ethers.providers.Web3Provider(connection)
        const signer = provider.getSigner()
        const contract = new ethers.Contract(commerceAddress,RacksItemsv3.abi, signer)
        const transaction = await contract.listTicket(formInput.tries.toString(), formInput.hours.toString(), formInput.price.toString())
    
        setProcessing(false)
        setProcessingPhase("")
        setShowForm(false)
        loadOwned()
        }catch{
          setShowForm(false)
          setProcessing(false)
          setProcessingPhase("")
        }
      
    }else{
      alert("Parámetros incorrectos!")
    }
    
    
  }
  async function loadItems() {
    /* create a generic provider and query for unsold market items */
    const web3Modal = new Web3Modal()
    const connection = await web3Modal.connect()
    const provider = new ethers.providers.Web3Provider(connection)
    const signer = provider.getSigner()
    const account = await signer.getAddress()

    const contract = new ethers.Contract(commerceAddress,RacksItemsv3.abi, signer)
    const data = await contract.getTicketsOnSale();

    /*
    *  map over items returned from smart contract and format 
    *  them as well as fetch their token metadata
    */
    const items = await Promise.all(data
      .filter( item => item.owner!=account)
      .map(async i => {

      
      let price=i.price.toNumber()
      let duration=i.duration.toNumber()
      let tries = i.numTries.toNumber()
      let owner = i.owner.toString()
  
      let item = {
        owner,
        price,
        duration,
        tries
      }
      
      return item
      
    }))
    setUser(account)
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
  
  
  else if (loadingState === 'loaded' ) return (
    <div className='flex bg-gradient-to-r from-soft'>
      
      <Sidebar/>
    <div className='flex w-full'>
      {items.length?(
    <div className="  ml-4 flex flex-col w-full md:w-1/2 items-center py-8  justify-start">
            {
              items
                .map
            ((item, i) => (
              <div  key={i} className='border border-main  w-full  flex mb-4 justify-between px-8  rounded items-center bg-main/70' >
        
              
                <p className='flex justify-center text-sm font-bold'>{item.owner.substring(0, 5)}...</p>
                <p className='flex justify-center items-center space-x-2 text-sm font-bold'><p>{item.tries}</p>
                <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-briefcase" viewBox="0 0 16 16">
                  <path d="M6.5 1A1.5 1.5 0 0 0 5 2.5V3H1.5A1.5 1.5 0 0 0 0 4.5v8A1.5 1.5 0 0 0 1.5 14h13a1.5 1.5 0 0 0 1.5-1.5v-8A1.5 1.5 0 0 0 14.5 3H11v-.5A1.5 1.5 0 0 0 9.5 1h-3zm0 1h3a.5.5 0 0 1 .5.5V3H6v-.5a.5.5 0 0 1 .5-.5zm1.886 6.914L15 7.151V12.5a.5.5 0 0 1-.5.5h-13a.5.5 0 0 1-.5-.5V7.15l6.614 1.764a1.5 1.5 0 0 0 .772 0zM1.5 4h13a.5.5 0 0 1 .5.5v1.616L8.129 7.948a.5.5 0 0 1-.258 0L1 6.116V4.5a.5.5 0 0 1 .5-.5z"/>
                  </svg> </p>
                <p className='flex justify-center text-sm font-bold'> {item.duration}h</p>
                <button  className="bg-secondary text-main font-bold rounded px-8 py-1 hover:bg-soft" onClick={()=>buyTicket(item)}>{item.price} RKS</button>
             </div>
            
            ))
          }
         
    </div>) : (<h1 className="px-flex flex-col w-full md:w-1/2 items-center   justify-start 20 py-10 text-3xl">No hay tickets en venta</h1>)}
      
      
    
    
    <div className='h-screen sticky top-0  hidden md:flex lg.flex flex-col py-16 px-16 secondary w-1/2'>
      
      
      <div className='bg-main rounded p-8 pb-32'>
        
        
          {(ticket.ownerOrSpender==2|| ticket.ownerOrSpender==0) ?(
             <div className='flex flex-col md:flex-col lg:flex-row items-center space-x-8'>
               <img src="/face.png" className='w-24 h-24 md:w-36 md:h-36 lg:w-48 lg:h-48 mb-16 '/>
               <p className='pb-16 text-xl font-bold'>{user.substring(0,15)}...  </p>

            </div>
          ):(
            <div className='flex flex-col md:flex-col lg:flex-row items-center space-x-8'>
               <img src={profilePic} className='w-24 rounded-full h-24 md:w-36 md:h-36 lg:w-48 lg:h-48 mb-16 '/>
               <p className='pb-16 text-xl font-bold'>{user.substring(0,15)}...  </p>

            </div>
          )}


         
       
        {
         ticket.ownerOrSpender==1?(
           <div className='w-full mx-auto flex items-center  justify-between  h-16 rounded'>
              <div className='flex items-center'><div className='h-2 w-2 mr-4 rounded-full bg-orange '></div><p className='font-semibold'>VIP</p></div>
              <button className='bg-red rounded hover:bg-main  px-4 py-2' onClick={renderListTicket}>Vender ticket</button>
           </div>
         ): ticket.ownerOrSpender==2?(
          <div className='w-full mx-auto flex flex-col  justify-between  h-16 rounded'>
             <div className='flex items-center'>
               <p className='font-semibold'>Estado: En uso, {ticketState.message}</p>
               <div className={` h-2 w-2 ml-4 rounded-full  ${ticketState.color}`} ></div>
              </div>
              <div className='font-semibold mb-4'>Tiradas de caja disponibles: {ticket.triesLeft}</div>
              <div className='font-semibold'>El ticket se liquidará en : {ticket.durationLeft} horas</div>
           
          </div>
        ):ticket.ownerOrSpender==3?(
          <div className='w-full mx-auto flex items-center  justify-between  h-16 rounded'>
             <div className='flex flex-col justify-center'>
               <div className={` h-2 w-2 mr-4 rounded-full  ${ticketState.color}`} ></div>
            <p className='font-semibold'>Delegado:{ticketState.message}
            </p>
            <p>Tiempo para la liquidación : {ticket.durationLeft} horas</p>
          </div>
           
          </div>
        ):ticket.ownerOrSpender==4?(
          <div>
            En venta
          </div>
        ):(<div>
          No tienes permisos VIP
        </div>

        
        )
        
        }
        

      </div>
    </div>{showForm && (
        <div className=' w-full flex flex-col justify-center items-center fixed'> 
        <div className='flex '>

<div className='flex flex-col h-screen w-full sticky top-0'>
<div class="mainscreen  ">
  

<div class="card">

<div class="leftside">
  <img src="/ticket.png" className="product m-8"/>
</div>
<div class="rightside">
  <form action="">
     
    <div className='flex justify-between'><h1 className='font-semibold'>TICKET RACKS</h1>
    <button onClick={()=>{setProcessing(false);setShowForm(false) ; setProcessingPhase("")}}><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-x-lg" viewBox="0 0 16 16">
<path d="M2.146 2.854a.5.5 0 1 1 .708-.708L8 7.293l5.146-5.147a.5.5 0 0 1 .708.708L8.707 8l5.147 5.146a.5.5 0 0 1-.708.708L8 8.707l-5.146 5.147a.5.5 0 0 1-.708-.708L7.293 8 2.146 2.854Z"/>
</svg></button></div>
    <h2 className='text-soft'>Modelo exclusivo de Racks Items</h2>
    <p>Tiradas de caja</p>
    <input onChange={e=>updateFormInput({...formInput, tries: e.target.value }) } type="number" class="inputbox" name="name" required />
    <p>Duración (máximo 168 horas)</p>
    <input onChange={e=>updateFormInput( {...formInput, hours: e.target.value}) } type="number" class="inputbox" name="name" required />
    <p>Precio (RKS)</p>
    <input onChange={e=>updateFormInput({...formInput, price: e.target.value}) } type="number" class="inputbox" name="name" required />
    

  
<div class="expcvv">


  
</div>
   {
         processing ? (
          <div>
           <div  className="button flex justify-center bg-red-40 "> <div class="vender"><div></div><div></div><div></div></div></div>
           <div className='text-soft flex flex-col w-full items-center pt-4'> {processingPhase} </div>
          </div>

         ):(
         <div onClick={()=>listTicket()} className="button cursor-pointer flex justify-center bg-red hover:bg-red/40">Vender</div>)
       }

   
  </form>
</div>
</div>
</div>


</div>




    
</div>
  </div>
      )} </div>   </div>
  )
  
  
}