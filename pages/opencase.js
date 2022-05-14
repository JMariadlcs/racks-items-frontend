import React from 'react'
import Image from 'next/image'
import Sidebar from './components/Sidebar'
export default function opencase() {
  return (
    <div className='flex'>
        <Sidebar/>
        <div className='flex absolute  justify-center marco items-center'>
          <div className='item1'>

          </div>
          <div className='item2'></div>

           </div>
        <div className='flex justify-center'>
        <section className="slideshow bg-main">
            <div className='entire-content'>
                <div className="content-carrousel ">
                     <figure className='flex justify-center items-center shadow bg-secondary ticker-red'><Image width="100" height="100" src="/reloj.png"/></figure>
                     <figure className='flex justify-center items-center shadow bg-secondary ticker-pink'><Image width="100" height="100" src="/napa.png"/></figure>
                     <figure className='flex justify-center items-center shadow bg-secondary ticker-blue'><Image width="100" height="100" src="/guante.png"/></figure>
                     <figure className='flex justify-center items-center shadow bg-secondary ticker-red'><Image width="100" height="100" src="/reloj.png"/></figure>
                     <figure className='flex justify-center items-center shadow bg-secondary ticker-pink'><Image width="100" height="100" src="/napa.png"/></figure>
                     <figure className='flex justify-center items-center shadow bg-secondary ticker-blue'><Image width="100" height="100" src="/guante.png"/></figure>
                        <figure className='flex justify-center items-center shadow bg-secondary ticker-red'><Image width="100" height="100" src="/reloj.png"/></figure>
                        <figure className='flex justify-center items-center shadow bg-secondary ticker-pink'><Image width="100" height="100" src="/napa.png"/></figure>
                        <figure className='flex justify-center items-center shadow bg-secondary ticker-blue'><Image width="100" height="100" src="/guante.png"/></figure>
                      
                </div>    
            </div>
        </section>
        </div>
    </div>
  )
}



