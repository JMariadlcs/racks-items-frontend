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

export default function Tickets() {
  const [ticketOnSale, setTicketOnSale] = useState({})
  const [marketContract, setMarketContract] = useState()
  const [tokenContract, setTokenContract] = useState()
  const [userAddress, setUserAddress] = useState("")
  const [userBalance , setUserBalance] = useState()
  const [allowance , setAllowance] = useState()
  const [formInput, updateFormInput] = useState({ tries: 0, hours: 0, price : 0})  
  const [processing, setProcessing] = useState(false);
  const [processingPhase, setProcessingPhase] =  useState("")
  const [profilePic , setProfilePic]= useState("")
  const [showForm,setShowForm] = useState(false)
  const [ticket, setTicket] = useState({})
  const [ticketState, setTicketState]= useState({})
  const [items, setItems] = useState([])
  const [loadingState, setLoadingState] = useState('not-loaded')
  
  useEffect(() => {
    if(marketContract){
      marketContract.on("ticketBought" , (ticketId, oldOwner, newOwner, price) =>{
        if(oldOwner == userAddress) loadData()

      })
    }
    loadData()
    if (window.ethereum) {
      window.ethereum.on("accountsChanged", (accounts) => {
        loadData()
    })}
  }, [])
  
  async function loadData(){

    const web3Modal = new Web3Modal()
    const connection = await web3Modal.connect()
    const provider = new ethers.providers.Web3Provider(connection)
    const signer = provider.getSigner()
    const market = new ethers.Contract(commerceAddress,RacksItemsv3.abi, signer)
    const token = new ethers.Contract(tokenAddress, RacksToken.abi, signer)
    const account = await signer.getAddress()

    setMarketContract(market)
    setTokenContract(token)
    setUserAddress(account)

    const ticketOnwership = await market.getUserTicket(account)
    const {0: durationLeft, 1: triesLeft, 2:ownerOrSpender, 3:ticketPrice} = ticketOnwership;
    const userTicket = {
     durationLeft: ticketOnwership.durationLeft.toNumber(),
     triesLeft : ticketOnwership.triesLeft.toNumber(),
     ownerOrSpender : ticketOnwership.ownerOrSpender.toNumber(),
     ticketPrice : ticketOnwership.ticketPrice.toNumber()
    }
    
    setTicket(userTicket)

    if(ticket.ownerOrSpender==0){
      const response = await token.balanceOf(account)
      const response2 = await token.allowance(account, commerceAddress)
      const balance = response.toNumber()
      const approved = response2.toNumber()
      setUserBalance(balance)
      setAllowance(approved)
    }

    const tickets = await market.getTicketsOnSale();

  
    const items = await Promise.all(tickets
      .filter(item => item.owner!=account)
      .map(async i => {

      let ticketId= i.ticketId.toString()
      let price=i.price.toNumber()
      let duration=i.duration.toNumber()
      let tries = i.numTries.toNumber()
      let owner = i.owner.toString()
  
      let item = {
        ticketId,
        owner,
        price,
        duration,
        tries
      }
      
      return item
      
    }))

    setItems(items)
    setLoadingState('loaded') 

    if(ownerOrSpender==4){
      const tickets = await market.getTicketsOnSale();
      const items = await Promise.all(tickets
        .filter(item => item.owner==account)
        .map(async i => {

        let ticketId= i.ticketId.toString()
        let price=i.price.toNumber()
        let duration=i.duration.toNumber()
        let tries = i.numTries.toNumber()
        let owner = i.owner.toString()
        
        let item = {
          ticketId,
          owner,
          price,
          duration,
          tries
        }

        setTicketOnSale(item)

      }))
    
    }
    
    if(ticket.ownerOrSpender!=0 && ticket.ownerOrSpender!=3){
      // this should fetch the MRCrypto`s uri
      const response =await fetch("https://arweave.net/u2pCDNJIPg8-yfI00u5V_kfqpR5c952nqoOLEM2_mXE")
      const data = await response.json()
      const URI = data.image
      setProfilePic(URI)
     
    }
    if(ticket.ownerOrSpender==3){
      if(ticket.durationLeft===0 ||ticket.triesLeft===0){
        setTicketState({color:"bg-green", message:"Disponible"})
      }else{
        setTicketState({color:"bg-red", message:"En uso"})
      }
  }


    if( ticket.ownerOrSpender==2 ){
      if(ticket.durationLeft===0 ||ticket.triesLeft==0){
        setTicketState({color:"bg-red", message:"Caducado"})
      }else{
        setTicketState({color:"bg-green", message:"Disponible"})
      }
  }

  }

  async function changeTicketConditions(){
    if(
      formInput.price>0
      && formInput.hours <=168
      && formInput.tries >0

    ){
      try{
        setProcessing(true)
        setProcessingPhase("Cambiando las condiciones...")
        const transaction = await marketContract.changeTicketConditionsFrom(useerAddress, formInput.tries.toString(), formInput.hours.toString(), formInput.price.toString())
        await transaction.wait()
        setProcessing(false)
        setProcessingPhase("")
        setShowForm(false)
        loadData()
        }catch{
          setShowForm(false)
          setProcessing(false)
          setProcessingPhase("")
        }
      
    }else{
      alert("Parámetros incorrectos!")
    }
  
  }

  async function claimTicketBack(){
    try{
    const transaction = await marketContract.claimTicketBackFrom(userAddress)
    await transaction.wait()
    loadData()

    }catch{
      console.log("error")
    }

  }
  
  async function buyTicket(item){

    if(ticket.ownerOrSpender==0){

      if(userBalance<item.price && allowance<item.price){
        alert("Fondos insuficientes")
      }else{

        if(allowance<item.price){
          const approval = await tokenContract.approve(commerceAddress , item.price.toString())
          await approval.wait()
        }
        
        const transaction2 = await marketContract.buyTicket(item.ticketId );
        await transaction2.wait()
        loadData()


      }

    }else{
      alert("Un ususario VIP no puede comprar otros tickets")
    }
  }

  async function unlistTicket(){
    try{
      transaction = await marketContract.unListTicketFrom(userAddress)
      await transaction.wait()
      loadData()

    }catch{
      console.log("Error")
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
        const transaction = await marketContract.listTicketFrom(userAddress, formInput.tries.toString(), formInput.hours.toString(), formInput.price.toString())
        await transaction.wait()
        setProcessing(false)
        setProcessingPhase("")
        setShowForm(false)
        loadData()
        }catch{
          setShowForm(false)
          setProcessing(false)
          setProcessingPhase("")
        }
      
    }else{
      alert("Parámetros incorrectos!")
    }
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
                .map((item, i) => (
                  <div  key={i} className='border border-main  w-full  flex mb-4 justify-between px-8  rounded items-center bg-main/70' >
                    <p className='flex justify-center text-sm font-bold'>{item.owner.substring(0, 5)}...</p>
                    <div className='flex justify-center items-center space-x-2 text-sm font-bold'>
                      <p>{item.tries}</p>
                      <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-briefcase" viewBox="0 0 16 16">
                        <path d="M6.5 1A1.5 1.5 0 0 0 5 2.5V3H1.5A1.5 1.5 0 0 0 0 4.5v8A1.5 1.5 0 0 0 1.5 14h13a1.5 1.5 0 0 0 1.5-1.5v-8A1.5 1.5 0 0 0 14.5 3H11v-.5A1.5 1.5 0 0 0 9.5 1h-3zm0 1h3a.5.5 0 0 1 .5.5V3H6v-.5a.5.5 0 0 1 .5-.5zm1.886 6.914L15 7.151V12.5a.5.5 0 0 1-.5.5h-13a.5.5 0 0 1-.5-.5V7.15l6.614 1.764a1.5 1.5 0 0 0 .772 0zM1.5 4h13a.5.5 0 0 1 .5.5v1.616L8.129 7.948a.5.5 0 0 1-.258 0L1 6.116V4.5a.5.5 0 0 1 .5-.5z"/>
                      </svg> 
                    </div>
                    <p className='flex justify-center text-sm font-bold'> {item.duration}h</p>
                    <button  className="bg-secondary text-main font-bold rounded px-8 py-1 hover:bg-soft" onClick={()=>buyTicket(item)}>{item.price} RKS</button>
                  </div>
               ))
            }
          </div>) : (
            <h1 className="px-20 py-10 text-md  w-full md:w-1/2 items-center   justify-start 20 ">No hay tickets en venta</h1>
            )
        }
          <div className='h-screen sticky top-0  hidden md:flex lg.flex flex-col py-16 px-16 secondary w-1/2'>
            <div className='bg-main rounded p-8 pb-32'>
                {(ticket.ownerOrSpender==2|| ticket.ownerOrSpender==0) ?(
                    <div className='flex flex-col md:flex-col lg:flex-row items-center'>
                      <img src="/face.png" className='w-24 h-24 md:w-36 md:h-36 lg:w-48 lg:h-48 mb-16 '/>
                      <p className='ml-8 pb-16 text-sm md:text-md lg:text-lg font-bold'>{userAddress.substring(0,15)}...  </p>
                    </div>
                  ):(
                    <div className='flex flex-col md:flex-col lg:flex-row items-center '>
                       <img src={profilePic} className='w-24 rounded-full h-24 md:w-36 md:h-36 lg:w-48 lg:h-48 mb-16 '/>
                       <p className='pb-16 ml-8 text-sm md:text-md lg:text-lg font-bold'>{userAddress.substring(0,15)}...  </p>     
                    </div>
                  )
                }      

                {
                 ticket.ownerOrSpender==1?(
                   <div className='w-full mx-auto flex flex-col lg:flex-row  px-auto items-center   justify-between  h-16 rounded'>
                      <div className='flex items-center'><div className='h-2 w-2 mr-4 rounded-full bg-blue '></div><p className='font-semibold'>VIP</p></div>
                      <button className='bg-blue rounded hover:bg-blue/30  text-sm md:text-md lg:text-lg px-4 py-2' onClick={renderListTicket}>Vender ticket</button>
                   </div>
                 ): ticket.ownerOrSpender==2?(
                  <div className='w-full mx-auto flex flex-col   px-auto   justify-between  h-16 rounded'>
                     <div className='flex items-center'>
                        <p className="text-sm md:text-md lg:text-md" > Con permiso, {ticketState.message}</p>
                        <div className={`h-2 w-2 ml-4 rounded-full  ${ticketState.color}`} ></div>
                      </div>
                      <div className=' text-sm md:text-md lg:text-md mb-4'>Tiradas de caja disponibles: {ticket.triesLeft}</div>
                  <div className='text-sm md:text-md lg:text-md '>El ticket se liquidará en : {(ticket.durationLeft/60).toFixed(2)} h</div>

                  </div>
                ):ticket.ownerOrSpender==3?(
                  <div className='w-full mx-auto flex flex-col lg:flex-row  px-auto items-center   justify-between  h-16 rounded'>
                     <div className='flex flex-col lg:flex-row justify-center'> 
                     <div className='flex items-center mr-8'>
                        <p className='font-semibold'> Prestado, {ticketState.message}</p>
                        <div className={` h-2 w-2 ml-4 rounded-full  ${ticketState.color}`} ></div>
                      </div>
                       {(ticketState.message=="Disponible") && (
                          <button onClick={claimTicketBack} className ="bg-green rounded hover:bg-green/30  text-sm md:text-md lg:text-lg px-4 py-2"> Recuperar ticket</button>
                       )}
                    </div>
                  </div>
                ):ticket.ownerOrSpender==4?(
                  <div className="w-full mx-auto flex flex-col   px-auto    justify-between  h-16 rounded">
                    <div>
                      <div className='flex items-center'>
                        <p className="text-sm md:text-md lg:text-md" >En venta</p> 
                        <div className='flex space-between '>

                      <button onClick={renderListTicket} className ="  text-sm md:text-md lg:text-lg px-4 py-2"> 
                        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="orange" class="bi bi-pencil-fill" viewBox="0 0 16 16">
                          <path d="M12.854.146a.5.5 0 0 0-.707 0L10.5 1.793 14.207 5.5l1.647-1.646a.5.5 0 0 0 0-.708l-3-3zm.646 6.061L9.793 2.5 3.293 9H3.5a.5.5 0 0 1 .5.5v.5h.5a.5.5 0 0 1 .5.5v.5h.5a.5.5 0 0    1 .5.5v.5h.5a.5.5 0                    0 1 .5.5v.207l6.5-6.5zm-7.468 7.468A.5.5 0 0 1 6 13.5V13h-.5a.5.5 0 0 1-.5-.5V12h-.5a.5.5 0 0 1-.5-.5V11h-.5a.5.5 0 0 1-.5-.5V10h-.5a.499.499 0    0 1-.175-.032l-.179.178a.5.5 0 0 0-.11.168l-2 5a.5.5 0 0                    0 .65.65l5-2a.5.5 0 0 0 .168-.11l.178-.178z"/>
                        </svg>
                      </button>

                      <button onClick={unlistTicket} className =""> <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16"    fill="red" class="bi bi-file-x" viewBox="0 0 16 16">
                          <path d="M6.146 6.146a.5.5 0 0 1 .708 0L8 7.293l1.146-1.147a.5.5 0 1 1 .708.708L8.707 8l1.147 1.146a.5.5 0 0 1-.708.708L8 8.707 6.854 9.854a.5.5 0 0 1-.708-.708L7.293 8 6.146 6.854a.    5.5 0 0 1 0-.708z"/>
                          <path d="M4 0a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h8a2 2 0 0 0 2-2V2a2 2 0 0 0-2-2H4zm0 1h8a1 1 0 0 1 1 1v12a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V2a1 1 0 0 1 1-1z"/>
                        </svg>
                      </button>

                  </div>
                  </div>

                    
                    <div className='border  hidden flex-row border-main bg-secondary  w-full  lg:flex mb-4 justify-between px-8  rounded md:items-start items-center bg-main/70' >
                    <div className='flex justify-center items-center space-x-2 text-sm font-bold'>
                      <p className='text-main text-sm md:text-md lg:text-md'>{ticketOnSale.tries}</p>
                      <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="main" className="bi bi-briefcase" viewBox="0 0 16 16">
                        <path d="M6.5 1A1.5 1.5 0 0 0 5 2.5V3H1.5A1.5 1.5 0 0 0 0 4.5v8A1.5 1.5 0 0 0 1.5 14h13a1.5 1.5 0 0 0 1.5-1.5v-8A1.5 1.5 0 0 0 14.5 3H11v-.5A1.5 1.5 0 0 0 9.5 1h-3zm0 1h3a.5.5 0 0 1 .5.5V3H6v-.5a.5.5 0 0 1 .5-.5zm1.886 6.914L15 7.151V12.5a.5.5 0 0 1-.5.5h-13a.5.5 0 0 1-.5-.5V7.15l6.614 1.764a1.5 1.5 0 0 0 .772 0zM1.5 4h13a.5.5 0 0 1 .5.5v1.616L8.129 7.948a.5.5 0 0 1-.258 0L1 6.116V4.5a.5.5 0 0 1 .5-.5z"/>
                      </svg> 
                    </div>
                    <p className='flex text-sm md:text-md lg:text-md text-main justify-center  font-bold'> {ticketOnSale.duration}h</p>
                    <p  className=" text-main text-sm md:text-md lg:text-md font-bold  " >{ticketOnSale.price} RKS</p>
                    </div>
                    


                  </div>
               
                </div>
                ):(<div>
                  No tienes permisos VIP
                </div>
                )
               }


            </div>
          </div>
          {showForm && (
            <div className=' w-full flex flex-col justify-center mb-16 items-center fixed '> 
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
                          <button onClick={()=>{setProcessing(false);setShowForm(false) ; setProcessingPhase("")}}>
                            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-x-lg" viewBox="0 0 16 16">
                              <path d="M2.146 2.854a.5.5 0 1 1 .708-.708L8 7.293l5.146-5.147a.5.5 0 0 1 .708.708L8.707 8l5.147 5.146a.5.5 0 0 1-.708.708L8 8.707l-5.146 5.147a.5.5 0 0 1-.708-.708L7.293 8 2.146 2.854Z"/>
                            </svg>
                          </button>
                        </div>
                        <h2 className='text-soft'>Modelo exclusivo de Racks Items</h2>
                        <p>Tiradas de caja</p>
                        <input onChange={e=>updateFormInput({...formInput, tries: e.target.value }) } type="number" class="inputbox" name="name" required />
                        <p>Duración (máximo 168 horas)</p>
                        <input onChange={e=>updateFormInput( {...formInput, hours: e.target.value}) } type="number" class="inputbox" name="name" required />
                        <p>Precio (RKS)</p>
                        <input onChange={e=>updateFormInput({...formInput, price: e.target.value}) } type="number" class="inputbox" name="name" required />
                        <div class="expcvv"></div>
                        {
                        processing ? (
                         <div>
                          <div  className="button flex justify-center bg-red-40 "> <div class="vender"><div></div><div></div><div></div></div></div>
                          <div className='text-soft flex flex-col w-full items-center pt-4'> {processingPhase} </div>
                         </div>

                        ):(
                        
                            <div onClick={()=>{
                              if(ticket.ownerOrSpender==1){
                                listTicket()

                              }else{
                                changeTicketConditions()
                              }
                              }} className="button cursor-pointer flex justify-center bg-red hover:bg-red/40">
                              {ticket.ownerOrSpender==1?(
                                <div>Vender</div>

                              ):(
                                <div>Modificar</div>
                              )}
                            </div>
                         
                         
                            
                          )
                        }
                        </form>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            )} 
        </div>   
      </div>
    )
  }