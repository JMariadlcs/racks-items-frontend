import React from 'react'
import Image from "next/Image"
import { buyItem } from '../market'

export default function Item({imageSrc, itemName, ticker, price, itemfunction}) {
  return (
    <div className='border border-main  overflow-hidden flex-col h-96 items-center bg-main/70' >
        <div className={`absolute rounded w-2 h-8 bg-secondary ${ticker}`}></div>
        <Image src={imageSrc} height="240" width="240" className="w-full h-36"/>
        <p className='flex justify-center text-sm font-bold'>{itemName}</p>
        <p className='flex justify-center text-sm font-semibold'>{price} MATIC</p>
        
    </div>
  )
}

