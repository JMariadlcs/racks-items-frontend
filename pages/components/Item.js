import React from 'react'
import Image from "next/Image"


export default function Item({imagesrc, name, ticker, precio}) {
  return (
    <div className='border border-main  overflow-hidden flex-col h-96 items-center bg-main/70' >
        <div className={`absolute rounded w-2 h-8 bg-secondary ${ticker}`}></div>
        <Image src={imagesrc} height="240" width="240" className="w-full h-36"/>
        <p className='flex justify-center text-sm font-bold'>{name}</p>
        <p className='flex justify-center text-sm font-semibold'>{precio}</p>
        <button className='w-full bg-secondary text-main px-8 mt-4 hover:bg-soft'>Comprar</button>
        <Image src="/racks2.png" height="10" width="50"/>
    </div>
  )
}

