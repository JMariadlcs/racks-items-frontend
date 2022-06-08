import Head from 'next/head'
import Image from 'next/image'
import styles from '../styles/Home.module.css'
import Link from 'next/dist/client/link'

export default function Home() {
  return (
    <div className="presentacion  flex flex-col items-center  ">
      <div className='w-full pb-96 backdrop-blur-sm pt-36  flex flex-col items-center p-8  h-96 bg-main/70 rounded'>
        <div className='flex  space-x-1 items-center mb-8'>
          <Image src="/racksLogo.png" width="200" height="70" />
          <p className='neon font-whisper text-4xl'>Items</p>
          
         
          </div>
        <div className='mb-8'>
        

        </div>
        <div className='space-x-4'>  
        
          <Link href="/market">
          <button className='go'>
            Entrar
          </button>
          </Link>
          <Link href = "/docs">
          <button className='docs'>
            Documentación
          </button>
          </Link>
        </div>
        <div className='bg-red/30 p-4 mt-16 w-70 h-70'>Atencion! Este es un prototipo para testeo desplegando 
        en la testnet Mumbai de Polygon.

        </div>
  
   

      </div>
      <footer className='bg-soft/30 border-t py-8 pb-48 px-4 w-full h-36 backdrop-blur-sm'>
        <div className='Scrooge w-1/2  flex flex-col'>
          <div className='flex items-center space-x-4 twitter'>
      <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="currentColor" class="bi bi-twitter" viewBox="0 0 16 16">
        <path d="M5.026 15c6.038 0 9.341-5.003 9.341-9.334 0-.14 0-.282-.006-.422A6.685 6.685 0 0 0 16 3.542a6.658 6.658 0 0 1-1.889.518 3.301 3.301 0 0 0 1.447-1.817 6.533 6.533 0 0 1-2.087.793A3.286 3.286 0 0 0 7.875 6.03a9.325 9.325 0 0 1-6.767-3.429 3.289 3.289 0 0 0 1.018 4.382A3.323 3.323 0 0 1 .64 6.575v.045a3.288 3.288 0 0 0 2.632 3.218 3.203 3.203 0 0 1-.865.115 3.23 3.23 0 0 1-.614-.057 3.283 3.283 0 0 0 3.067 2.277A6.588 6.588 0 0 1 .78 13.58a6.32 6.32 0 0 1-.78-.045A9.344 9.344 0 0 0 5.026 15z"/>
        </svg>
        <p className='text-sm'>@devScrooge</p>

        </div>
        <div className='mt-4 mb-16 flex items-center space-x-4 mail'>
        <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="currentColor" class="bi bi-envelope-fill" viewBox="0 0 16 16">
  <path d="M.05 3.555A2 2 0 0 1 2 2h12a2 2 0 0 1 1.95 1.555L8 8.414.05 3.555ZM0 4.697v7.104l5.803-3.558L0 4.697ZM6.761 8.83l-6.57 4.027A2 2 0 0 0 2 14h12a2 2 0 0 0 1.808-1.144l-6.57-4.027L8 9.586l-1.239-.757Zm3.436-.586L16 11.801V4.697l-5.803 3.546Z"/>
</svg>
          
          <p className='text-sm'>0xdevScrooge@gmail.com</p>
          </div>

        </div>
      </footer>
      
    </div>
  )
}
