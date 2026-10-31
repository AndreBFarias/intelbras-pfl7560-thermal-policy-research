/*
 * nl_tela - gera, no aparelho, as telas da suite de boot do PFL7560 (bloco 9A, contrato C-tela
 * em docs/sprints/2026-10-30-bloco-9-suite-de-boot.md).
 *
 *   nl_tela aviso|resumo <campos.txt> <saida.png> <dir_fontes>
 *
 * Grava um PNG 1920x1080 RGB. Sai 0 ok, 1 erro (fonte, arquivo, gravacao, campo invalido),
 * 2 uso errado.
 *
 * campos.txt: uma "chave=valor" por linha, ASCII puro. Texto nao ASCII vai como \uXXXX (BMP),
 * quebra de linha como \n e a barra como \\. Chave desconhecida e ignorada; linha vazia ou
 * comecada por # tambem. Byte nao ASCII cru (erro de quem escreveu o arquivo) vira "?" com um
 * aviso em stderr: a tela sai assim mesmo. Texto que nao cabe e cortado com reticencias e
 * avisado em stderr ("nl_tela: truncado: ..."), nunca passa da margem.
 *
 * Fontes: as cinco IBM Plex de <dir_fontes>; a que faltar cai na reserva do sistema
 * (/system/fonts: Roboto-Regular, Roboto-Bold, DroidSansMono; NL_TELA_SISTEMA troca a pasta,
 * para o harness do PC). Sem nenhuma das duas para um estilo: sai 1. Glifo que a fonte nao
 * tem sai da reserva, se carregada, ou vira "?".
 *
 * Compilar (NDK r27c):
 *   armv7a-linux-androideabi24-clang -O2 -Wall -o nl_tela nl_tela.c -lm
 * No PC (harness): cc -O2 -Wall -Wextra -o nl_tela nl_tela.c -lm
 */
#include <errno.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

/* terceiros (dominio publico): avisos deles nao sao nossos */
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-function"
#pragma GCC diagnostic ignored "-Wsign-compare"
#pragma GCC diagnostic ignored "-Wunused-parameter"
#pragma GCC diagnostic ignored "-Wmissing-field-initializers"
#define STBTT_STATIC
#define STB_TRUETYPE_IMPLEMENTATION
#include "terceiros/stb_truetype.h"
#define STB_IMAGE_WRITE_STATIC
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "terceiros/stb_image_write.h"
#pragma GCC diagnostic pop

#define LARG 1920
#define ALT 1080
#define MAX_ARQ 65536          /* campos.txt maior que isso nao e da suite */
#define MAX_LINHA 1024         /* bytes por linha do campos.txt, chave incluida */
#define MAX_TXT 1024           /* caracteres por campo, depois de decodificar */
#define MAX_PASSOS 6
#define MAX_GRUPOS 4
#define MAX_ITENS 6
#define MAX_DICAS 3
#define MAX_FONTE (16 << 20)

/* paleta do C-tela */
#define C_FUNDO  0x0E1116
#define C_CARTAO 0x171B21
#define C_REALCE 0x242A33      /* cartao do passo em andamento */
#define C_TEXTO  0xF2F3F5
#define C_SEC    0xA9AFB8
#define C_FIO    0x2A3038
#define C_OK     0x6FD6A6
#define C_CORR   0xF2B451
#define C_ATEN   0xF07560

/* ---- imagem e mistura de cor ------------------------------------------------- */

static unsigned char tela[ALT][LARG][3];
static float lin[256];            /* sRGB -> linear */
static unsigned char srgb[4096];  /* linear (0..4095) -> sRGB */

static void cores_init(void) {
  for (int i = 0; i < 256; i++) {
    double c = i / 255.0;
    lin[i] = (float)(c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4));
  }
  for (int i = 0; i < 4096; i++) {
    double l = i / 4095.0;
    double c = l <= 0.0031308 ? l * 12.92 : 1.055 * pow(l, 1 / 2.4) - 0.055;
    srgb[i] = (unsigned char)(c * 255 + 0.5);
  }
}

/* mistura a cor no pixel com cobertura a (0..1), em luz linear (gamma certo) */
static void ponto(int x, int y, uint32_t cor, float a) {
  if (x < 0 || y < 0 || x >= LARG || y >= ALT || a <= 0) return;
  if (a > 1) a = 1;
  unsigned char *px = tela[y][x];
  for (int k = 0; k < 3; k++) {
    unsigned char c = (cor >> (16 - 8 * k)) & 0xff;
    if (a >= 1) { px[k] = c; continue; }
    float l = lin[px[k]] + (lin[c] - lin[px[k]]) * a;
    px[k] = srgb[(int)(l * 4095 + 0.5f)];
  }
}

static void fundo(uint32_t cor) {
  for (int y = 0; y < ALT; y++)
    for (int x = 0; x < LARG; x++) ponto(x, y, cor, 1);
}

/* retangulo com cantos arredondados (raio r), cobertura das quinas por 4x4 amostras */
static void retangulo(int x0, int y0, int w, int h, int r, uint32_t cor) {
  for (int y = y0; y < y0 + h; y++)
    for (int x = x0; x < x0 + w; x++) {
      int dx = x < x0 + r ? x0 + r - x : (x >= x0 + w - r ? x - (x0 + w - r) + 1 : 0);
      int dy = y < y0 + r ? y0 + r - y : (y >= y0 + h - r ? y - (y0 + h - r) + 1 : 0);
      if (!dx || !dy) { ponto(x, y, cor, 1); continue; }
      float cx = x < x0 + r ? x0 + r : x0 + w - r, cy = y < y0 + r ? y0 + r : y0 + h - r;
      int dentro = 0;
      for (int sy = 0; sy < 4; sy++)
        for (int sx = 0; sx < 4; sx++) {
          float px = x + (sx + 0.5f) / 4 - cx, py = y + (sy + 0.5f) / 4 - cy;
          dentro += px * px + py * py <= (float)r * r;
        }
      ponto(x, y, cor, dentro / 16.0f);
    }
}

/* ponto de estado: disco de raio r centrado em (cx,cy); anel=1 desenha so o contorno */
static void disco(float cx, float cy, float r, uint32_t cor, int anel) {
  float ri = r - 2.2f;
  for (int y = (int)floorf(cy - r) - 1; y <= (int)ceilf(cy + r) + 1; y++)
    for (int x = (int)floorf(cx - r) - 1; x <= (int)ceilf(cx + r) + 1; x++) {
      int dentro = 0;
      for (int sy = 0; sy < 4; sy++)
        for (int sx = 0; sx < 4; sx++) {
          float px = x + (sx + 0.5f) / 4 - cx, py = y + (sy + 0.5f) / 4 - cy, d2 = px * px + py * py;
          dentro += d2 <= r * r && (!anel || d2 >= ri * ri);
        }
      ponto(x, y, cor, dentro / 16.0f);
    }
}

/* ---- fontes ------------------------------------------------------------------ */

enum { E_REG, E_SEMI, E_BOLD, E_MONO, E_MONO_SEMI, N_EST };
static const char *const PRIMARIA[N_EST] = {
  "IBMPlexSansCondensed-Regular.ttf", "IBMPlexSansCondensed-SemiBold.ttf",
  "IBMPlexSansCondensed-Bold.ttf", "IBMPlexMono-Regular.ttf", "IBMPlexMono-SemiBold.ttf" };
static const char *const RESERVA[N_EST] = {
  "Roboto-Regular.ttf", "Roboto-Bold.ttf", "Roboto-Bold.ttf", "DroidSansMono.ttf", "DroidSansMono.ttf" };

struct fonte { char caminho[512]; unsigned char *dados; stbtt_fontinfo info; };
static struct fonte fontes[2 * N_EST];
static int nfontes;
static struct fonte *cadeia[N_EST][2];   /* primaria e reserva de cada estilo (NULL = ausente) */

/* a stb_truetype nao confere offset nenhum: um TTF truncado (copia interrompida) faz ela ler
 * fora do buffer. Confere o diretorio de tabelas do arquivo: cabe no arquivo e cada tabela
 * (offset + tamanho) tambem. Devolve o offset da fonte 0 ou -1. */
static uint32_t be32(const unsigned char *p) {
  return (uint32_t)p[0] << 24 | (uint32_t)p[1] << 16 | (uint32_t)p[2] << 8 | p[3];
}
static int sfnt_ok(const unsigned char *d, long n) {
  if (n < 16) return -1;                /* GetFontOffsetForIndex le ate o byte 15 numa TTC */
  int off = stbtt_GetFontOffsetForIndex(d, 0);
  if (off < 0 || (long)off + 12 > n) return -1;
  long nt = d[off + 4] << 8 | d[off + 5];
  if (nt == 0 || (long)off + 12 + 16 * nt > n) return -1;
  for (long i = 0; i < nt; i++) {
    uint32_t o = be32(d + off + 12 + 16 * i + 8), l = be32(d + off + 12 + 16 * i + 12);
    if (o > (uint32_t)n || l > (uint32_t)n - o) return -1;
  }
  return off;
}

/* carrega (uma vez por arquivo) a fonte do caminho; NULL se nao existe ou nao e TTF valido */
static struct fonte *carregar(const char *dir, const char *nome) {
  char cam[512];
  if (snprintf(cam, sizeof cam, "%s/%s", dir, nome) >= (int)sizeof cam) return NULL;
  for (int i = 0; i < nfontes; i++) if (strcmp(fontes[i].caminho, cam) == 0) return &fontes[i];
  FILE *f = fopen(cam, "rb");
  if (!f) return NULL;
  struct fonte *ft = &fontes[nfontes];
  long n = fseek(f, 0, SEEK_END) == 0 ? ftell(f) : -1;
  if (n <= 0 || n > MAX_FONTE || fseek(f, 0, SEEK_SET) != 0) {
    fprintf(stderr, "nl_tela: %s: tamanho invalido\n", cam); fclose(f); return NULL;
  }
  ft->dados = malloc(n);
  if (!ft->dados || fread(ft->dados, 1, n, f) != (size_t)n) {
    fprintf(stderr, "nl_tela: %s: nao consegui ler\n", cam); fclose(f); free(ft->dados); return NULL;
  }
  fclose(f);
  int off = sfnt_ok(ft->dados, n);
  if (off < 0 || !stbtt_InitFont(&ft->info, ft->dados, off)) {
    fprintf(stderr, "nl_tela: %s: nao e uma fonte TrueType valida\n", cam); free(ft->dados); return NULL;
  }
  snprintf(ft->caminho, sizeof ft->caminho, "%s", cam);
  nfontes++;
  return ft;
}

static int fontes_init(const char *dir) {
  const char *sis = getenv("NL_TELA_SISTEMA");
  if (!sis || !*sis) sis = "/system/fonts";
  for (int e = 0; e < N_EST; e++) {
    cadeia[e][0] = carregar(dir, PRIMARIA[e]);
    cadeia[e][1] = carregar(sis, RESERVA[e]);
    if (!cadeia[e][0] && !cadeia[e][1]) {
      fprintf(stderr, "nl_tela: sem fonte para %s: nem %s/%s nem %s/%s\n",
              PRIMARIA[e], dir, PRIMARIA[e], sis, RESERVA[e]);
      return 1;
    }
    if (!cadeia[e][0]) {
      fprintf(stderr, "nl_tela: aviso: %s/%s ausente, usando a reserva %s/%s\n",
              dir, PRIMARIA[e], sis, RESERVA[e]);
      cadeia[e][0] = cadeia[e][1]; cadeia[e][1] = NULL;
    }
  }
  return 0;
}

/* glifo do caractere no estilo: primaria, reserva, ou o "?" da primaria */
static int glifo(int est, uint32_t cp, struct fonte **f) {
  for (int i = 0; i < 2; i++) {
    struct fonte *ft = cadeia[est][i];
    int g = ft ? stbtt_FindGlyphIndex(&ft->info, (int)cp) : 0;
    if (g) { *f = ft; return g; }
  }
  *f = cadeia[est][0];
  return stbtt_FindGlyphIndex(&(*f)->info, '?');
}

static int tem_glifo(int est, uint32_t cp) {
  for (int i = 0; i < 2; i++)
    if (cadeia[est][i] && stbtt_FindGlyphIndex(&cadeia[est][i]->info, (int)cp)) return 1;
  return 0;
}

static float escala(struct fonte *f, float px) { return stbtt_ScaleForMappingEmToPixels(&f->info, px); }

/* altura das maiusculas (do "H") no estilo e tamanho: alinha o texto pela linha de topo */
static float altura_maiuscula(int est, float px) {
  struct fonte *f; int g = glifo(est, 'H', &f), x0, y0, x1, y1;
  stbtt_GetGlyphBox(&f->info, g, &x0, &y0, &x1, &y1);
  return y1 * escala(f, px);
}

/* ---- texto ------------------------------------------------------------------- */

struct txt { uint32_t c[MAX_TXT]; int n; };

/* desenha (pinta=1) ou so mede s[0..n) a partir de x na linha de base y; devolve a largura.
 * esp = espacamento extra entre letras, em px. */
static float corrida(int est, float px, float esp, float x, int y, uint32_t cor,
                     const uint32_t *s, int n, int pinta) {
  float x0 = x;
  struct fonte *fant = NULL; int gant = 0;
  for (int i = 0; i < n; i++) {
    struct fonte *f; int g = glifo(est, s[i] == '\n' ? ' ' : s[i], &f);
    float sc = escala(f, px);
    if (fant == f && gant) x += stbtt_GetGlyphKernAdvance(&f->info, gant, g) * sc;
    if (pinta) {
      int ix = (int)floorf(x), w, h, ox, oy;
      unsigned char *bm = stbtt_GetGlyphBitmapSubpixel(&f->info, sc, sc, x - ix, 0, g, &w, &h, &ox, &oy);
      if (bm) {
        for (int yy = 0; yy < h; yy++)
          for (int xx = 0; xx < w; xx++)
            if (bm[yy * w + xx]) ponto(ix + ox + xx, y + oy + yy, cor, bm[yy * w + xx] / 255.0f);
        stbtt_FreeBitmap(bm, NULL);
      }
    }
    int av, lsb;
    stbtt_GetGlyphHMetrics(&f->info, g, &av, &lsb);
    x += av * sc + (i + 1 < n ? esp : 0);
    fant = f; gant = g;
  }
  return x - x0;
}

static float largura(int est, float px, float esp, const uint32_t *s, int n) {
  return corrida(est, px, esp, 0, 0, 0, s, n, 0);
}

/* o harness exige zero destes avisos nos exemplos do dono */
static void aviso_truncado(const char *campo, const uint32_t *s, int n) {
  fprintf(stderr, "nl_tela: truncado: %s: \"", campo);
  for (int i = 0; i < n && i < 80; i++) fputc(s[i] < 0x80 && s[i] >= 0x20 ? (int)s[i] : '?', stderr);
  fprintf(stderr, "%s\"\n", n > 80 ? "..." : "");
}

/* uma linha de texto que nunca passa de maxw: o que sobra vira reticencias. alinha: 0 esquerda
 * (x e a borda esquerda), 1 direita (x e a borda direita). Devolve a largura desenhada. */
static float linha(int est, float px, float esp, float x, int y, uint32_t cor, const uint32_t *s, int n,
                   float maxw, int alinha, const char *campo) {
  float w = largura(est, px, esp, s, n);
  if (w <= maxw) {
    corrida(est, px, esp, alinha ? x - w : x, y, cor, s, n, 1);
    return w;
  }
  aviso_truncado(campo, s, n);
  static const uint32_t ret1[] = { 0x2026 }, ret3[] = { '.', '.', '.' };
  const uint32_t *r = tem_glifo(est, 0x2026) ? ret1 : ret3;
  int nr = r == ret1 ? 1 : 3;
  float wr = largura(est, px, esp, r, nr) + esp;
  int lo = 0, hi = n;     /* maior k com s[0..k) + reticencias dentro de maxw (busca binaria) */
  while (lo < hi) {
    int m = (lo + hi + 1) / 2;
    if (largura(est, px, esp, s, m) + wr <= maxw) lo = m; else hi = m - 1;
  }
  int k = lo;
  while (k > 0 && (s[k - 1] == ' ' || s[k - 1] == '\n')) k--;
  float wk = largura(est, px, esp, s, k) + (k ? esp : 0);
  float x0 = alinha ? x - (wk + wr - esp) : x;
  if (wk + wr - esp > maxw) return 0;          /* nem as reticencias cabem */
  corrida(est, px, esp, x0, y, cor, s, k, 1);
  corrida(est, px, esp, x0 + wk, y, cor, r, nr, 1);
  return wk + wr - esp;
}

/* como linha(), mas antes de cortar reduz o tamanho de pmax ate pmin (passo de 1 px) */
static float linha_ajustada(int est, float pmax, float pmin, float x, int y, uint32_t cor, const uint32_t *s,
                            int n, float maxw, const char *campo) {
  float px = pmax;
  while (px > pmin && largura(est, px, 0, s, n) > maxw) px -= 1;
  return linha(est, px, 0, x, y, cor, s, n, maxw, 0, campo);
}

/* quebra s em ate maxl linhas de largura maxw (por palavra; \n forca a quebra). Grava
 * inicio/tamanho de cada linha; a ultima, se o texto nao couber, leva o resto (e o corte da
 * funcao linha poe as reticencias). Devolve o numero de linhas. */
static int quebrar(int est, float px, const struct txt *t, float maxw, int maxl, int *ini, int *tam) {
  int nl = 0, i = 0;
  while (nl < maxl) {
    while (i < t->n && t->c[i] == ' ') i++;
    if (i >= t->n) break;
    /* palavras enquanto couberem (a primeira sempre entra; se for larga demais, e cortada) */
    int fim = i, j = i;
    while (j < t->n && t->c[j] != '\n') {
      int k = j;
      while (k < t->n && t->c[k] != ' ' && t->c[k] != '\n') k++;
      if (fim > i && largura(est, px, 0, t->c + i, k - i) > maxw) break;
      fim = k; j = k;
      while (j < t->n && t->c[j] == ' ') j++;
    }
    int prox = j < t->n && t->c[j] == '\n' ? j + 1 : j, resta = 0;
    for (int k = prox; k < t->n && !resta; k++) resta = t->c[k] != ' ' && t->c[k] != '\n';
    if (nl == maxl - 1 && resta) { ini[nl] = i; tam[nl++] = t->n - i; return nl; }
    ini[nl] = i; tam[nl++] = fim - i;
    i = prox;
  }
  return nl;
}

/* desenha uma linha que pode conter \n do campo: quebras viram espaco */
static void sem_quebra(struct txt *t) {
  for (int i = 0; i < t->n; i++) if (t->c[i] == '\n') t->c[i] = ' ';
}

/* ---- campos ------------------------------------------------------------------ */

enum { S_OK, S_CORR, S_ATEN, S_INFO, S_PEND, S_NADA };
enum { F_FILA, F_AGORA, F_FEITO };

static struct campos {
  struct txt etapa, canto, titulo, texto, rodape, destaque;
  int tem_titulo, tom, dest_estado;
  int npassos;
  struct { struct txt nome; int fase, res; } passo[MAX_PASSOS];
  int ngrupos;
  struct { struct txt nome; int nitens; struct { struct txt rot, val; int est; } item[MAX_ITENS]; } grupo[MAX_GRUPOS];
  int ndicas;
  struct txt dica[MAX_DICAS];
} C;

static int nlinha;               /* linha do campos.txt em leitura (mensagens) */

static int hex(int c) {
  if (c >= '0' && c <= '9') return c - '0';
  if (c >= 'a' && c <= 'f') return c - 'a' + 10;
  if (c >= 'A' && c <= 'F') return c - 'A' + 10;
  return -1;
}

/* decodifica s[0..n) em t: \uXXXX (BMP; substituto ou zero viram "?"), \n, \\; outra
 * sequencia com barra fica como esta. Byte nao ASCII cru vira "?" (com aviso). */
static void decodificar(const char *s, int n, struct txt *t) {
  int cru = 0;
  t->n = 0;
  for (int i = 0; i < n && t->n < MAX_TXT; i++) {
    unsigned char c = (unsigned char)s[i];
    uint32_t cp = c;
    if (c >= 0x80) { cru = 1; cp = '?'; }
    else if (c == '\\' && i + 1 < n) {
      if (s[i + 1] == 'n') { cp = '\n'; i++; }
      else if (s[i + 1] == '\\') { cp = '\\'; i++; }
      else if (s[i + 1] == 'u' && i + 5 < n && hex(s[i + 2]) >= 0 && hex(s[i + 3]) >= 0
               && hex(s[i + 4]) >= 0 && hex(s[i + 5]) >= 0) {
        cp = (uint32_t)(hex(s[i + 2]) << 12 | hex(s[i + 3]) << 8 | hex(s[i + 4]) << 4 | hex(s[i + 5]));
        if (cp == 0 || (cp >= 0xD800 && cp <= 0xDFFF)) cp = '?';
        i += 5;
      }
    } else if (c < 0x20) cp = ' ';   /* tab e outros controles */
    t->c[t->n++] = cp;
  }
  if (cru) fprintf(stderr, "nl_tela: aviso: linha %d tem byte nao ASCII cru (use \\uXXXX); trocado por ?\n", nlinha);
}

/* divide v em ate max partes por '|'; devolve quantas */
static int partes(const char *v, int n, const char **p, int *tam, int max) {
  int k = 0, ini = 0;
  for (int i = 0; i <= n; i++)
    if (i == n || v[i] == '|') {
      if (k == max) return max + 1;
      p[k] = v + ini; tam[k++] = i - ini; ini = i + 1;
    }
  return k;
}

static int palavra(const char *s, int n, const char *const *lista, int nl) {
  for (int i = 0; i < nl; i++) if ((int)strlen(lista[i]) == n && strncmp(s, lista[i], n) == 0) return i;
  return -1;
}

static const char *const NOMES_ESTADO[] = { "ok", "corrigido", "atencao", "info", "pendente" };
static const char *const NOMES_FASE[] = { "fila", "agora", "feito" };

static int erro_campo(const char *msg, const char *v, int n) {
  fprintf(stderr, "nl_tela: linha %d: %s: \"%.*s\"\n", nlinha, msg, n > 60 ? 60 : n, v);
  return 1;
}

static int campo(int resumo, const char *k, int nk, const char *v, int nv) {
  const char *p[4]; int t[4], np;
#define CH(nome) (nk == (int)strlen(nome) && strncmp(k, nome, nk) == 0)
  if (CH("titulo")) { decodificar(v, nv, &C.titulo); C.tem_titulo = 1; }
  else if (CH("canto")) decodificar(v, nv, &C.canto);
  else if (CH("rodape")) decodificar(v, nv, &C.rodape);
  else if (!resumo && CH("etapa")) decodificar(v, nv, &C.etapa);
  else if (!resumo && CH("texto")) decodificar(v, nv, &C.texto);
  else if (!resumo && CH("tom")) {
    static const char *const tons[] = { "normal", "alerta" };
    if ((C.tom = palavra(v, nv, tons, 2)) < 0) return erro_campo("tom invalido (normal|alerta)", v, nv);
  } else if (!resumo && CH("passo")) {
    if (C.npassos == MAX_PASSOS) return erro_campo("passos demais (ate 6)", v, nv);
    np = partes(v, nv, p, t, 3);
    if (np < 2 || np > 3) return erro_campo("passo deve ser nome|fila,agora,feito[|resultado]", v, nv);
    int fase = palavra(p[1], t[1], NOMES_FASE, 3);
    int res = np == 3 ? palavra(p[2], t[2], NOMES_ESTADO, 5) : S_NADA;
    if (fase < 0 || res < 0 || res == S_INFO || t[0] == 0) return erro_campo("passo invalido", v, nv);
    decodificar(p[0], t[0], &C.passo[C.npassos].nome);
    C.passo[C.npassos].fase = fase; C.passo[C.npassos++].res = res;
  } else if (resumo && CH("destaque")) decodificar(v, nv, &C.destaque);
  else if (resumo && CH("destaque_estado")) {
    if ((C.dest_estado = palavra(v, nv, NOMES_ESTADO, 3)) < 0)
      return erro_campo("destaque_estado invalido (ok|corrigido|atencao)", v, nv);
  } else if (resumo && CH("grupo")) {
    if (C.ngrupos == MAX_GRUPOS) return erro_campo("grupos demais (ate 4)", v, nv);
    decodificar(v, nv, &C.grupo[C.ngrupos++].nome);
  } else if (resumo && CH("item")) {
    if (C.ngrupos == 0) return erro_campo("item antes do primeiro grupo", v, nv);
    int g = C.ngrupos - 1;
    if (C.grupo[g].nitens == MAX_ITENS) return erro_campo("itens demais no grupo (ate 6)", v, nv);
    np = partes(v, nv, p, t, 3);
    int est = np == 3 ? palavra(p[2], t[2], NOMES_ESTADO, 5) : -1;
    if (np != 3 || est < 0) return erro_campo("item deve ser rotulo|valor|ok,corrigido,atencao,info,pendente", v, nv);
    int i = C.grupo[g].nitens++;
    decodificar(p[0], t[0], &C.grupo[g].item[i].rot);
    decodificar(p[1], t[1], &C.grupo[g].item[i].val);
    C.grupo[g].item[i].est = est;
  } else if (resumo && CH("dica")) {
    if (C.ndicas == MAX_DICAS) return erro_campo("dicas demais (ate 3)", v, nv);
    decodificar(v, nv, &C.dica[C.ndicas++]);
  }
#undef CH
  return 0;   /* chave desconhecida: ignorada */
}

static int ler_campos(const char *arq, int resumo) {
  FILE *f = fopen(arq, "rb");
  if (!f) { fprintf(stderr, "nl_tela: %s: %s\n", arq, strerror(errno)); return 1; }
  static char buf[MAX_ARQ + 1];
  size_t n = fread(buf, 1, sizeof buf, f);
  int erro_leitura = ferror(f);
  fclose(f);
  if (erro_leitura) { fprintf(stderr, "nl_tela: %s: erro de leitura\n", arq); return 1; }
  if (n > MAX_ARQ) { fprintf(stderr, "nl_tela: %s: maior que %d bytes\n", arq, MAX_ARQ); return 1; }
  C.dest_estado = S_OK;
  size_t i = 0;
  nlinha = 0;
  while (i < n) {
    size_t j = i;
    while (j < n && buf[j] != '\n') j++;
    nlinha++;
    if (j - i > MAX_LINHA) { fprintf(stderr, "nl_tela: linha %d: mais de %d bytes\n", nlinha, MAX_LINHA); return 1; }
    size_t fim = j;
    if (fim > i && buf[fim - 1] == '\r') fim--;
    const char *l = buf + i, *eq = memchr(l, '=', fim - i);
    if (fim > i && l[0] != '#') {
      if (!eq) fprintf(stderr, "nl_tela: aviso: linha %d sem '=': ignorada\n", nlinha);
      else if (memchr(l, 0, fim - i)) { fprintf(stderr, "nl_tela: linha %d: byte zero\n", nlinha); return 1; }
      else if (campo(resumo, l, (int)(eq - l), eq + 1, (int)(fim - i) - (int)(eq - l) - 1)) return 1;
    }
    i = j + 1;
  }
  if (!C.tem_titulo || C.titulo.n == 0) { fprintf(stderr, "nl_tela: %s: falta titulo=\n", arq); return 1; }
  return 0;
}

/* ---- desenho comum ----------------------------------------------------------- */

#define MARGEM 110

static uint32_t cor_estado(int est) {
  switch (est) {
    case S_OK: return C_OK;
    case S_CORR: return C_CORR;
    case S_ATEN: return C_ATEN;
    case S_INFO: return C_TEXTO;
    default: return C_SEC;
  }
}

/* texto fixo do programa, escrito com os mesmos escapes do campos.txt (o fonte e ASCII) */
static struct txt fixo(const char *s) {
  struct txt t;
  decodificar(s, (int)strlen(s), &t);
  return t;
}

/* linha de base para que o topo das maiusculas fique em y */
static int base_em(int est, float px, int y) { return y + (int)lroundf(altura_maiuscula(est, px)); }

/* ---- aviso ------------------------------------------------------------------- */

static void tela_aviso(void) {
  const int topo = 104, pe = ALT - 100, larg_util = LARG - 2 * MARGEM;
  fundo(C_FUNDO);

  /* linha de cima: etapa (esquerda) e canto (direita), Mono 26 secundario */
  int b0 = base_em(E_MONO, 26, topo);
  sem_quebra(&C.etapa); sem_quebra(&C.canto);
  float wc = C.canto.n ? largura(E_MONO, 26, 0, C.canto.c, C.canto.n) : 0;
  if (wc > larg_util / 2 - 24) wc = larg_util / 2 - 24;
  if (C.canto.n) linha(E_MONO, 26, 0, LARG - MARGEM, b0, C_SEC, C.canto.c, C.canto.n, wc, 1, "canto");
  if (C.etapa.n) linha(E_MONO, 26, 0, MARGEM, b0, C_SEC, C.etapa.c, C.etapa.n,
                       larg_util - wc - (C.canto.n ? 48 : 0), 0, "etapa");

  /* titulo: ate 3 linhas (\n), Bold 92; tom=alerta pinta na cor de atencao */
  const float pt = 100; const int passo_t = 108;
  int ini[8], tam[8];
  int nt = quebrar(E_BOLD, pt, &C.titulo, larg_util, 3, ini, tam);
  int y = base_em(E_BOLD, pt, b0 + 88);
  for (int i = 0; i < nt; i++, y += passo_t)
    linha(E_BOLD, pt, 0, MARGEM, y, C.tom ? C_ATEN : C_TEXTO, C.titulo.c + ini[i], tam[i], larg_util, 0, "titulo");
  int fim_titulo = y - passo_t;

  /* rodape: Mono 24 secundario, embaixo */
  sem_quebra(&C.rodape);
  int b_rod = pe;
  if (C.rodape.n) linha(E_MONO, 24, 0, MARGEM, b_rod, C_SEC, C.rodape.c, C.rodape.n, larg_util, 0, "rodape");
  int topo_rodape = b_rod - (int)altura_maiuscula(E_MONO, 24);

  /* passos: uma fileira de cartoes acima do rodape (4 colunas, ou uma por passo se mais) */
  int topo_passos = C.rodape.n ? topo_rodape - 64 : pe;
  if (C.npassos) {
    int ncol = C.npassos > 4 ? C.npassos : 4, gap = 20;
    float wcart = (larg_util - gap * (ncol - 1)) / (float)ncol;
    const float pn = 34; const int pad = 28, passo_n = 42;
    float wint = wcart - 2 * pad;
    int nlin = 1;
    for (int i = 0; i < C.npassos; i++) {
      int a[2], b[2];
      if (quebrar(E_SEMI, pn, &C.passo[i].nome, wint, 2, a, b) > 1) nlin = 2;
    }
    int b_est = (int)altura_maiuscula(E_MONO, 24) + pad;            /* base da linha de estado */
    int b_nome = b_est + 30 + (int)altura_maiuscula(E_SEMI, pn);     /* base do nome */
    int hcart = b_nome + (nlin - 1) * passo_n + pad + 6;
    int yc = topo_passos - hcart;
    topo_passos = yc;
    for (int i = 0; i < C.npassos; i++) {
      int xc = MARGEM + (int)lroundf(i * (wcart + gap));
      int wc_i = (int)lroundf((i + 1) * (wcart + gap) - gap) - (xc - MARGEM);
      int fase = C.passo[i].fase, res = C.passo[i].res;
      retangulo(xc, yc, wc_i, hcart, 10, fase == F_AGORA ? C_REALCE : C_CARTAO);
      char num[8]; snprintf(num, sizeof num, "%d", i + 1);
      struct txt tn = fixo(num);
      corrida(E_MONO, 24, 0, xc + pad, yc + b_est, C_SEC, tn.c, tn.n, 1);
      /* estado a direita: ponto + palavra */
      const char *pal; uint32_t cor; int anel = 0;
      if (fase == F_FILA) { pal = "na fila"; cor = C_SEC; anel = 1; }
      else if (fase == F_AGORA) { pal = "agora"; cor = C_TEXTO; }
      else if (res == S_NADA) { pal = "feito"; cor = C_OK; }
      else {
        static const char *const pr[] = { "ok", "corrigido", "aten\\u00e7\\u00e3o", "", "pendente" };
        pal = pr[res]; cor = cor_estado(res); anel = res == S_PEND;
      }
      struct txt te = fixo(pal);
      float we = largura(E_MONO, 24, 0, te.c, te.n);
      float xd = xc + wc_i - pad;
      corrida(E_MONO, 24, 0, xd - we, yc + b_est, cor, te.c, te.n, 1);
      float xh = altura_maiuscula(E_MONO, 24);
      disco(xd - we - 18, yc + b_est - xh / 2, 6, cor, anel);
      /* nome: ate 2 linhas */
      int a[2], b[2];
      int nn = quebrar(E_SEMI, pn, &C.passo[i].nome, wint, nlin, a, b);
      for (int k = 0; k < nn; k++)
        linha(E_SEMI, pn, 0, xc + pad, yc + b_nome + k * passo_n, fase == F_FILA ? C_SEC : C_TEXTO,
              C.passo[i].nome.c + a[k], b[k], wint, 0, "passo");
    }
  }

  /* texto: paragrafo Regular 38 secundario, ate onde couber acima dos passos */
  if (C.texto.n) {
    const float px = 40; const int passo_l = 58;
    int b = base_em(E_REG, px, fim_titulo + 60);
    int maxl = (topo_passos - 56 - b) / passo_l + 1;
    if (maxl > 8) maxl = 8;
    if (maxl < 1) maxl = 1;
    int nl = quebrar(E_REG, px, &C.texto, 1400, maxl, ini, tam);
    for (int i = 0; i < nl; i++)
      linha(E_REG, px, 0, MARGEM, b + i * passo_l, C_SEC, C.texto.c + ini[i], tam[i], 1400, 0, "texto");
  }
}

/* ---- resumo ------------------------------------------------------------------ */

static void tela_resumo(void) {
  const int topo = 72, larg_util = LARG - 2 * MARGEM;
  fundo(C_FUNDO);

  /* cabecalho: titulo + destaque (Bold 72) e canto (Mono 26) na mesma linha de base */
  const float pt = 72;
  int bt = base_em(E_BOLD, pt, topo);
  sem_quebra(&C.titulo); sem_quebra(&C.destaque); sem_quebra(&C.canto);
  float wc = C.canto.n ? largura(E_MONO, 24, 0, C.canto.c, C.canto.n) : 0;
  if (wc > larg_util / 2) wc = larg_util / 2;
  if (C.canto.n) linha(E_MONO, 24, 0, LARG - MARGEM, bt, C_SEC, C.canto.c, C.canto.n, wc, 1, "canto");
  float maxt = larg_util - (C.canto.n ? wc + 64 : 0), ph = pt;
  /* titulo e destaque na mesma linha: se nao cabem, os dois diminuem juntos (ate 56 px) antes
   * de cortar; a linha de base fica onde esta */
  for (; ph > 56; ph -= 2) {
    float w = largura(E_BOLD, ph, 0, C.titulo.c, C.titulo.n);
    if (C.destaque.n) w += 0.28f * ph + largura(E_BOLD, ph, 0, C.destaque.c, C.destaque.n);
    if (w <= maxt) break;
  }
  float wt = linha(E_BOLD, ph, 0, MARGEM, bt, C_TEXTO, C.titulo.c, C.titulo.n, maxt, 0, "titulo");
  if (C.destaque.n) {
    float esp = 0.28f * ph;
    linha(E_BOLD, ph, 0, MARGEM + wt + esp, bt, cor_estado(C.dest_estado), C.destaque.c, C.destaque.n,
          maxt - wt - esp, 0, "destaque");
  }

  /* rodape embaixo */
  sem_quebra(&C.rodape);
  int b_rod = ALT - 66;
  if (C.rodape.n) linha(E_MONO, 24, 0, MARGEM, b_rod, C_SEC, C.rodape.c, C.rodape.n, larg_util, 0, "rodape");
  int limite = b_rod - (int)altura_maiuscula(E_MONO, 24) - 36;

  /* faixa de dicas (se houver) logo acima do rodape */
  const float pd = 28; const int passo_d = 42, pad_d = 22;
  int hd = C.ndicas ? 2 * pad_d + C.ndicas * passo_d - (passo_d - (int)altura_maiuscula(E_REG, pd)) + 8 : 0;
  int topo_cart = bt + 44;
  int fundo_cart = limite - (C.ndicas ? hd + 24 : 0);

  /* cartoes dos grupos: 4 colunas, mesma altura de linha em todas */
  const int gap = 24, pad = 28, hcab = 72;
  const float pg = 30, pr = 26, pv = 34;
  float wcart = (larg_util - gap * (MAX_GRUPOS - 1)) / (float)MAX_GRUPOS;
  int maxit = 0;
  for (int g = 0; g < C.ngrupos; g++) if (C.grupo[g].nitens > maxit) maxit = C.grupo[g].nitens;
  int passo_i = maxit ? (fundo_cart - topo_cart - hcab - 10) / maxit : 0;
  if (passo_i > 116) passo_i = 116;
  /* folga da linha dividida por igual: do fio ao topo do rotulo e da base do valor ao fio seguinte */
  int folga = passo_i > 88 ? (passo_i - 88) / 2 : 0;
  int b_rot = 14 + folga + (int)altura_maiuscula(E_REG, pr);
  int b_val = b_rot + 18 + (int)altura_maiuscula(E_MONO_SEMI, pv);
  int hcart = hcab + maxit * passo_i + 10;
  if (passo_i < b_val + 10)
    fprintf(stderr, "nl_tela: aviso: pouco espaco vertical (passo %d)\n", passo_i);
  for (int g = 0; g < C.ngrupos; g++) {
    int xc = MARGEM + (int)lroundf(g * (wcart + gap));
    int wc_g = (int)lroundf((g + 1) * (wcart + gap) - gap) - (xc - MARGEM);
    float wint = wc_g - 2 * pad;
    retangulo(xc, topo_cart, wc_g, hcart, 10, C_CARTAO);
    sem_quebra(&C.grupo[g].nome);
    linha(E_SEMI, pg, 0.08f * pg, xc + pad, base_em(E_SEMI, pg, topo_cart + pad), C_SEC,
          C.grupo[g].nome.c, C.grupo[g].nome.n, wint, 0, "grupo");
    for (int i = 0; i < C.grupo[g].nitens; i++) {
      int yi = topo_cart + hcab + i * passo_i;
      int est = C.grupo[g].item[i].est;
      retangulo(xc + pad, yi, (int)wint, 2, 0, C_FIO);
      sem_quebra(&C.grupo[g].item[i].rot); sem_quebra(&C.grupo[g].item[i].val);
      /* rotulo e, na mesma linha, o ponto de estado na borda direita; o valor embaixo, na cor
       * do estado, com a largura toda (se nao couber, diminui ate 28 px antes de cortar) */
      float r = 6;
      linha(E_REG, pr, 0, xc + pad, yi + b_rot, C_SEC, C.grupo[g].item[i].rot.c, C.grupo[g].item[i].rot.n,
            wint - 2 * r - 16, 0, "item (rotulo)");
      float meio = yi + b_rot - altura_maiuscula(E_REG, pr) / 2;
      disco(xc + pad + wint - r, meio, r, est == S_INFO ? C_SEC : cor_estado(est), est == S_PEND);
      linha_ajustada(E_MONO_SEMI, pv, 28, xc + pad, yi + b_val, cor_estado(est), C.grupo[g].item[i].val.c,
                     C.grupo[g].item[i].val.n, wint, "item (valor)");
    }
  }

  /* dicas: faixa propria, marcador na cor de atencao */
  if (C.ndicas) {
    int yd = topo_cart + hcart + 24;
    retangulo(MARGEM, yd, larg_util, hd, 10, C_CARTAO);
    int b = base_em(E_REG, pd, yd + pad_d + 4);
    for (int i = 0; i < C.ndicas; i++, b += passo_d) {
      sem_quebra(&C.dica[i]);
      disco(MARGEM + pad + 6, b - altura_maiuscula(E_REG, pd) / 2, 6, C_ATEN, 0);
      linha(E_REG, pd, 0, MARGEM + pad + 32, b, C_TEXTO, C.dica[i].c, C.dica[i].n,
            larg_util - 2 * pad - 32, 0, "dica");
    }
  }
}

int main(int argc, char **argv) {
  if (argc != 5 || (strcmp(argv[1], "aviso") != 0 && strcmp(argv[1], "resumo") != 0)) {
    fprintf(stderr, "uso: nl_tela aviso|resumo <campos.txt> <saida.png> <dir_fontes>\n");
    return 2;
  }
  int resumo = argv[1][0] == 'r';
  cores_init();
  if (ler_campos(argv[2], resumo)) return 1;
  if (fontes_init(argv[4])) return 1;
  if (resumo) tela_resumo(); else tela_aviso();
  if (!stbi_write_png(argv[3], LARG, ALT, 3, tela, LARG * 3)) {
    fprintf(stderr, "nl_tela: nao consegui gravar %s\n", argv[3]);
    unlink(argv[3]);      /* so arquivo: remove() apagaria uma pasta vazia passada por engano */
    return 1;
  }
  return 0;
}
