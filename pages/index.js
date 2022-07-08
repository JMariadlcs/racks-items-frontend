import Head from 'next/head'
import Image from 'next/image'
import styles from '../styles/Home.module.css'
import Link from 'next/dist/client/link'

export default function Home({user, userConnected}) {
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
        
          
            {userConnected==true && (<Link href="/market">
              <button className='go'>
                       Entrar
              </button>  
            </Link>)
            }
         
         
          <Link href = "https://github.com/devScrooge/racks-items-backend/blob/main/README.md" target={"_blank"}>
          <button className='docs'>
            Documentación
          </button>
          </Link>
        </div>
        <div className='bg-red/30 p-4 mt-16 w-70 h-70'>Atencion! Este es un prototipo para testeo desplegando 
        en la testnet Mumbai de Polygon.

        </div>
  
   

      </div>
      <footer className='bg-soft/30 border-t py-8 pb-48 px-4 flex flex-col h-ful w-full backdrop-blur-sm'>
       
      </footer>
      
    </div>
  )
}
