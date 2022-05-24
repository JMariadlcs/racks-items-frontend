import React from 'react'
import Image from "next/Image"


export default function Owneditem({amo, ima, na, ti}) {
  return (
    <div className='border border-main  overflow-hidden flex-col h-96 items-center bg-main/70' >
        <div className={`absolute rounded w-2 h-8 bg-secondary ${ti}`}></div>
        <Image src={ima} height="240" width="240" className="w-full h-36"/>
        <p className='flex justify-center text-sm font-bold'>{na}</p>
        <p>Tienes : {amo}</p>

        
    </div>
  )
}