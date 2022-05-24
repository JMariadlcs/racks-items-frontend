import { ethers } from 'ethers'
import { useEffect, useState } from 'react'
import axios from 'axios'
import Web3Modal from 'web3modal'
import Sidebar from "./components/Sidebar"
import Item from "./components/Item"
import Image from "next"
import Owneditem from './components/Owneditem'
import {
  commerceAddress
} from '../config'

import TokenizedCommerce from '../build/contracts/TokenizedCommerce.json'
export default function opencase() {

  const itemList=[
    {
      name:"Guantes",
      imageSrc:"/items/guante.png",
      ticker:"ticker-blue"
    },
    {
      name:"Camiseta",
      imageSrc:"/items/camiseta.png",
      ticker: "ticker-blue"
    },
    {
      name:"Sudadera",
      imageSrc:"/items/sudadera.png",
      ticker: "ticker-pink"
    },
    {
      name:"Chamarrón",
      imageSrc:"/items/napa.png",
      ticker: "ticker-pink"
    },
    {
      name:"Zapatos",
      imageSrc:"/items/shoe.png",
      ticker: "ticker-red"
    },
    {
      name:"Watch",
      imageSrc:"/items/reloj.png",
      ticker: "ticker-red"
    },



  ]


  async function openCase() {
    /* needs the user to sign the transaction, so will use Web3Provider and sign it */
    const web3Modal = new Web3Modal()
    const connection = await web3Modal.connect()
    const provider = new ethers.providers.Web3Provider(connection)
    const signer = provider.getSigner()
    const account = await signer.getAddress()
    const contract = new ethers.Contract(commerceAddress,TokenizedCommerce.abi, signer)

    /* user will be prompted to pay the asking proces to complete the transaction */
    const openPrice = await contract.casePrice()
    const price = openPrice.toString()
    
    const transaction = await contract.openCase({
      value: price
    })

    await transaction.wait()
    contract.on("CaseOpened", (user, casePrice, item) => {
      let gotItem = item.toNumber();
      alert(`Te ha tocado ${itemList[gotItem].name}`)

  });
    


  

  }
  return (
    <div className='flex'>
        <Sidebar/>
        <div className='flex justify-center items-center h-full w-full open'>
        
          <div className='flex px-96 w-full justify-between items-center backdrop-blur-sm bg-main/30'>
              <button  onClick={()=>openCase()} className='go p-8 text-xl mx-86 mt-36 mb-96'>ABRIR</button>
          </div>

          
         

        </div>
       
    </div>
  )
}



