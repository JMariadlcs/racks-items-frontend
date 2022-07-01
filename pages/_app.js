import '../styles/globals.css'
import Link from 'next/link'
import Image from 'next/Image';
import { useEffect, useState } from 'react'



function MyApp({ Component, pageProps }) {
  const [walletConnected, setWalletConnected] = useState()
  const [userAddress , setUserAddress] = useState()
  const [insideDapp , setInsideDapp] = useState(false)
  useEffect(()=>{
    if(insideDapp){
      requestAccounts()
    }
    if(window.ethereum){
      
      window.ethereum.on("accountsChanged", (accounts) => {
      setWalletConnected(false)
      requestAccounts()
    
    })
    }
  },[])
  async function requestAccounts(){
    console.log("Requesting account...")
    if(window.ethereum){
      console.log("detected")
    }else{
      console.log("metamask not installed")
    }

    try{
      const accounts = await ethereum.request({ method: 'eth_requestAccounts' });
      const account = accounts[0];
      if(account.length){
      setWalletConnected(true)
      setUserAddress(account)}
      setInsideDapp(true)
      
    }catch{
      console.log("Error connecting...")
    }
  }
  return (
  <div>
    <header className='px-8 py-4 flex justify-between border-b border-secondary'>
      <nav className='flex justify-between items-center'>
        <Link href="/">
          <a className='flex space-x-2  items-center'>
            <Image src="/racksLogo.png" width="120" height="45" />
            <p className='neon font-whisper text-4xl'>Items</p>
          </a>
        </Link>

      </nav>
      {
        !walletConnected?(<button onClick={()=> requestAccounts()} className='go  mr-8'>Conectar</button>):(<div className='user flex justify-center items-baseline'>{userAddress.substring(0,5)}...{userAddress.substring(10,15)}</div>)
      }
     
    </header>
   
      <Component user={userAddress} userConnected={walletConnected} {...pageProps} />

 
  </div> 
  )
}

export default MyApp
