import { ethers } from 'ethers'
import { useEffect, useState } from 'react'
import axios from 'axios'
import Web3Modal from 'web3modal'
import Sidebar from "./components/Sidebar"
import Owneditem from "./components/Owneditem"
import Web3 from 'web3'
import Image from "next"
import {
  commerceAddress
} from '../config'

import TokenizedCommerce from '../build/contracts/TokenizedCommerce.json'


export default function Inventory() {
  const [items, setItems] = useState([])
  const [loadingState, setLoadingState] = useState('not-loaded')
  useEffect(() => {
    loadItems()
  }, [])
  


  

  
  async function loadItems() {
    const web3Modal = new Web3Modal()
    const connection = await web3Modal.connect()
    const provider = new ethers.providers.Web3Provider(connection)
    const signer = provider.getSigner()
    const account = await signer.getAddress()

    const contract = new ethers.Contract(commerceAddress,TokenizedCommerce.abi, signer)
    const data = await contract.viewItems(account);
  
    let counter =0;
    const items = await Promise.all(data.map(async i=> {
      
      let amount =  i.toNumber()
   
      
        
        let item = {
          tokenId: counter,
          amount : amount
        }
        counter ++;
        return item
        
      }))
    
   
    setItems(items)
    setLoadingState('loaded') 
  
  }
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
      name:"Reloj",
      imageSrc:"/items/reloj.png",
      ticker: "ticker-red"
    },



  ]
  
  if (loadingState === 'loaded' && !items.length) return (
    <div className='flex'>
      <Sidebar/>
    <h1 className="px-20 py-10 text-3xl">Tu inventario está vació</h1></div>
  )
  return (
    <div className='flex bg-gradient-to-r from-soft'>
    <Sidebar/>
    <div className=" grid grid-cols-1 mx-auto md:grid-cols-3 sm:grid-cols-2 lg:grid-cols-4 gap-4 pt-4">
    {
            items.map((item, i) =>(
              <div>
              <Owneditem key={i} amo={item.amount} ima={itemList[item.tokenId].imageSrc} na = {itemList[item.tokenId].name} ti={itemList[item.tokenId].ticker} />
             
              </div>
            )
            )
          }
    </div>
   
    </div>
  )
}