<nav>
   <TopMenu lItems={__anonVar0}>
   </TopMenu>
</nav>
<main>
   <slot>
   </slot>
</main>
<footer>
   web page by
</footer>
<script>
   import {taml} from '@jdeighan/string-input/taml'
   var __anonVar0;
   
   import TopMenu from 'C:/Users/johnd/cielo/test/components/TopMenu.svelte';
   
   __anonVar0 = taml(`---
   -
         label: Home
         url: /
   -
         label: Help
         lItems:
               -
                     label: About
                     url: /about
               -
                     label: Contact
                     url: /contact`);
</script>
<style>
   nav {
         grid-area: top;
         text-align: center;
   }
   
   main {
         grid-area: middle;
         overflow: auto;
         margin: 5px;
   }
   
   footer {
         grid-area: bottom;
         text-align: center;
         background-color: yellow;
   }
</style>
