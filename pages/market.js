import { ethers } from 'ethers'
import { useEffect, useState } from 'react'
import axios from 'axios'
import Web3Modal from 'web3modal'
import Sidebar from "./components/Sidebar"
import Item from "./components/Item"
import {
  commerceAddress
} from '../config'

import TokenizedCommerce from '../build/contracts/TokenizedCommerce.json'
export async function buyItem(item) {
  /* needs the user to sign the transaction, so will use Web3Provider and sign it */
  const web3Modal = new Web3Modal()
  const connection = await web3Modal.connect()
  const provider = new ethers.providers.Web3Provider(connection)
  const signer = provider.getSigner()
  const contract = new ethers.Contract(commerceAddress,TokenizedCommerce.abi, signer)
  
  /* user will be prompted to pay the asking proces to complete the transaction */
  const price = ethers.utils.parseUnits(item.price.toString(), 'ether')  
  const transaction = await contract.buyItem(item.marketItemId, {
    value: price
  })
  await transaction.wait()
  loadItems()
}

export default function Home() {
  
  const [items, setItems] = useState([])
  const [loadingState, setLoadingState] = useState('not-loaded')
  useEffect(() => {
    loadItems()
  }, [])


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

  
  async function loadItems() {
    /* create a generic provider and query for unsold market items */
    const provider = new ethers.providers.JsonRpcProvider("https://speedy-nodes-nyc.moralis.io/033c7c46afc666ebde825d34/polygon/mumbai")
    const contract = new ethers.Contract(commerceAddress,TokenizedCommerce.abi, provider)
    const data = await contract.getItemsOnSale()

    /*
    *  map over items returned from smart contract and format 
    *  them as well as fetch their token metadata
    */
    const items = await Promise.all(data.map(async i => {
      // const tokenUri = await contract.tokenURI(i.tokenId) hacerlo en variable
      
      let price=ethers.utils.formatUnits(i.price.toString(), 'ether');
      
  
      let item = {
        marketItemId: i.marketItemId.toNumber(),
        price,
        tokenId: i.tokenId.toNumber()
      }
      return item
    }))
    setItems(items)
    setLoadingState('loaded') 
  }
  
  if (loadingState === 'loaded' && !items.length) return (
    <div className='flex'>
      <Sidebar/>
    <h1 className="px-20 py-10 text-3xl">No items in marketplace</h1></div>
  )
  return (
    <div className='flex bg-gradient-to-r from-soft'>
    <Sidebar/>
    <div className="grid grid-cols-1 mx-auto md:grid-cols-3 sm:grid-cols-2 lg:grid-cols-4 gap-4 pt-4">
          {
            items.map((item, i) => (
              <div>
              <Item key={i}  itemFuncion={item} imageSrc={itemList[item.tokenId].imageSrc} itemName = {itemList[item.tokenId].name} ticker={itemList[item.tokenId].ticker} price={item.price}/>
              <button onClick={()=>buyItem(item)} className='w-full bg-secondary text-main px-8 mt-4 hover:bg-soft'>Comprar</button>
              </div>
            ))
          }
    </div>
   
    </div>
  )
}