#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
typedef void (*fn2)(void*, int);
typedef void (*fn1)(void*);
typedef int  (*fn0)(void);
int main(int argc, char** argv){
  setvbuf(stdout, 0, _IONBF, 0);
  if(argc<3){ printf("uso: lvdsctl <fmt|swap|bit|map> <valor>\n"); return 1; }
  void* h = dlopen("libhitvservice.so", RTLD_NOW|RTLD_GLOBAL);
  if(!h) h = dlopen("/vendor/lib/libhitvservice.so", RTLD_NOW|RTLD_GLOBAL);
  if(!h){ printf("dlopen FALHOU: %s\n", dlerror()); _exit(2); }
  fn0 sysinit=(fn0)dlsym(h,"HI_SYS_Init");
  if(sysinit){ int r=sysinit(); printf("[SYS_Init]=%d\n", r); }
  fn1 pinit=(fn1)dlsym(h,"_ZN11HiPanelCtrl4InitEv");
  if(pinit){ printf("[PanelCtrl::Init]...\n"); pinit((void*)0); printf(" ok\n"); }
  const char* sym=0;
  if(!strcmp(argv[1],"fmt"))  sym="_ZN11HiPanelCtrl13SetLvdsFormatE22HI_MW_PANEL_LVDS_FMT_E";
  else if(!strcmp(argv[1],"swap")) sym="_ZN11HiPanelCtrl11SetLvdsSwapE23HI_MW_PANEL_LVDS_SWAP_E";
  else if(!strcmp(argv[1],"bit"))  sym="_ZN11HiPanelCtrl14SetLvdsBitModeE22HI_MW_PANEL_BITWIDTH_E";
  else if(!strcmp(argv[1],"map"))  sym="_ZN11HiPanelCtrl10SetLvdsMapE22HI_MW_PANEL_LINKTYPE_E";
  fn2 f=(fn2)dlsym(h,sym);
  if(!f){ printf("dlsym FALHOU: %s\n", dlerror()); _exit(3); }
  int val=atoi(argv[2]);
  printf("[chamando %s(%d)]\n", argv[1], val);
  f((void*)0, val);
  printf("[RETORNOU OK]\n");
  fflush(stdout);
  _exit(0);
}
