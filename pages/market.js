import React from 'react'
import Sidebar from './components/Sidebar'
import Image from "next/Image"
import Item from './components/Item'
export default function market() {
  return (
    <div className='flex bg-gradient-to-r from-soft '>
      <Sidebar className=""/>  
      <div className="grid grid-cols-1 mx-auto md:grid-cols-3 sm:grid-cols-2 lg:grid-cols-4 gap-4 pt-4 px-4">
        <Item imagesrc="/guante.png" name="Guantes Racks" ticker="ticker-blue" precio="150 RCS"/>
        <Item imagesrc="/guante.png" name="Guantes Racks" ticker="ticker-blue" precio="150 RCS"/>
        <Item imagesrc="/guante.png" name="Guantes Racks" ticker="ticker-blue" precio="150 RCS"/>

        <Item imagesrc="/napa.png" name="Chamarrón nórdico" ticker="ticker-pink" precio="1000 RCS"/>
        <Item imagesrc="/guante.png" name="Guantes Racks" ticker="ticker-blue" precio="150 RCS"/>
        <Item imagesrc="/guante.png" name="Guantes Racks" ticker="ticker-blue" precio="150 RCS"/>
        <Item imagesrc="/guante.png" name="Guantes Racks" ticker="ticker-blue" precio="150 RCS"/>
        <Item imagesrc="/guante.png" name="Guantes Racks" ticker="ticker-blue" precio="150 RCS"/>
        <Item imagesrc="/guante.png" name="Guantes Racks" ticker="ticker-blue" precio="150 RCS"/>
        <Item imagesrc="/guante.png" name="Guantes Racks" ticker="ticker-blue" precio="150 RCS"/>
        
        <Item imagesrc="/reloj.png" name="RacksTrack™ | Reloj Racks" ticker="ticker-red" precio="200000 RCS"/>
        <Item imagesrc="/guante.png" name="Guantes Racks" ticker="ticker-blue" precio="150 RCS"/>
       
       
      </div>
     
      
        
        
    </div>
  )
}

