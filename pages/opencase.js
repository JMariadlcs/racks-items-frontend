import { ethers } from 'ethers'
import { useEffect, useState } from 'react'
import axios from 'axios'
import Web3Modal from 'web3modal'
import Sidebar from "./components/Sidebar"
import itemList from "../itemlist"
import { useRouter } from 'next/router'

import {
  commerceAddress,
  tokenAddress
} from '../config'

import RacksItemsv3 from '../build/contracts/RacksItemsv3.json'
import RacksToken from '../build/contracts/RacksToken.json'
import Link from 'next/link'

export default function Opencase({user, userConnected}) {
  const [opening, setOpening] = useState(false)
  const [vipState, setVipState]=useState(false)
  const [loadingState, setLoadingState]=useState(false)

  useEffect(() => {
    loadVipState()
    if (window.ethereum) {
      window.ethereum.on("accountsChanged", (accounts) => {
        setLoadingState(false)
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
    const {0: durationLeft, 1: triesLeft, 3:ownerOrSpender, 4:ticketPrice} = data;
    const dur= data[1].toNumber()
    console.log(dur)

    if(data[0].toNumber()==1 || data[0].toNumber()==3){
      setVipState(true)
    }


  }

  async function openCase() {
    /* needs the user to sign the transaction, so will use Web3Provider and sign it */
    const web3Modal = new Web3Modal()
    const connection = await web3Modal.connect()
    const provider = new ethers.providers.Web3Provider(connection)
    const signer = provider.getSigner()
    const account = await signer.getAddress()
    const Tokencontract = new ethers.Contract(tokenAddress,RacksToken.abi, signer)
    const contract = new ethers.Contract(commerceAddress,RacksItemsv3.abi, signer)

    /* user will be prompted to pay the asking proces to complete the transaction */
    const openPrice = await contract.getCasePrice()
    const price = openPrice.toString()
    
    const approval = await Tokencontract.approve(commerceAddress , price.toString())

    
    
    const transaction = await contract.openCase()

    await transaction.wait()
    contract.on("CaseOpened", (user, casePrice, item) => {
      let gotItem = item.toNumber();
      alert(`Te ha tocado ${itemList[gotItem].name}`)
     

  });
    

  }
  return (
    <div className='absolute w-full flex flex-col  bg-gradient-to-r from-soft '>
        <div className='flex'>
        <Sidebar/>
        <div class="mainscreen">
          {
            vipState?(
              <div>
                hfjdskhkdf
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
                  
          
        </div>
      </div>
       
    </div>
  )
}



