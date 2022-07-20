import { Html, Head, Main, NextScript } from 'next/document'

export default function Document() {

  return (
    <Html>
      <Head >

        <link href="//db.onlinewebfonts.com/c/55d433372d270829c51e2577a78ef12d?family=Monument+Extended" rel="stylesheet" type="text/css"/>
        <link rel="preconnect" href="https://fonts.googleapis.com"/>
        <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin/>
        <link href="https://fonts.googleapis.com/css2?family=Mandali&family=Poppins:wght@400;600;700&family=Whisper&display=swap" rel="stylesheet"/>

      </Head>

      
      <body className=" bg-main font-monument text-md  text-secondary scroll-smooth">
        <Main />
        <NextScript />
      </body>

    </Html>
  )
}