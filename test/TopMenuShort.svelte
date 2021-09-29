<div class="main">
   {#if hItem.url}
      <a href={hItem.url}>
      </a>
   {:else if hItem.lItems}
      <div class="dropdown">
      </div>
   {:else}
      <nav>
      </nav>
   {/if}
</div>
<script>
   export var hItem = undef;
</script>
