import '../styles/globals.css'
import Link from 'next/link'
import Image from 'next/Image';
import { useEffect, useState } from 'react'

function MyApp({ Component, pageProps }) {
  
  return (
  <div>
    <header className='px-8 py-4 border-b border-secondary'>
      <nav className='flex justify-between items-center'>
        <Link href="/">
          <a className='flex space-x-2  items-center'>
            <Image src="/racks.png" width="120" height="45" />
            <p className='neon font-whisper text-4xl'>Items</p>
          </a>
        </Link>

      </nav>
    </header>
   
      <Component {...pageProps} />

 
  </div> 
  )
}

export default MyApp
