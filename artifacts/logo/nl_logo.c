#include <errno.h>
#include <fcntl.h>
#include <math.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-function"
#pragma GCC diagnostic ignored "-Wsign-compare"
#pragma GCC diagnostic ignored "-Wunused-parameter"
#pragma GCC diagnostic ignored "-Wmissing-field-initializers"
#pragma GCC diagnostic ignored "-Wimplicit-fallthrough"
#define STBI_NO_STDIO
#define STBI_NO_SIMD
#define STBI_ONLY_JPEG
#define STB_IMAGE_IMPLEMENTATION
#include "terceiros/stb_image.h"
#define STBI_WRITE_NO_STDIO
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "terceiros/stb_image_write.h"
#pragma GCC diagnostic pop

#define L 1920
#define A 1080
#define TAM_PART 41943040L
#define JPEG_OFF 8192L
#define KEYLEN_OFF 0x78L
#define MAX_ENTRADA (8L << 20)
#define MAX_JPEG (256L << 10)
#define QUALIDADE 95
#define AREA_MIN_PCT 25

static unsigned char CABECALHO[KEYLEN_OFF];
static const char PPM_CAB[] = "P6\n1920 1080\n255\n";

static void cabecalho_conhecido(void) {
  memset(CABECALHO, 0, sizeof CABECALHO);
  memcpy(CABECALHO, "###", 4);
  CABECALHO[4] = 0x7c;
  memcpy(CABECALHO + 8, "LOGO_TABLE", 10);
  CABECALHO[0x28] = 0x50;
  memcpy(CABECALHO + 0x2c, "LOGO_KEY_FLAG", 13);
  CABECALHO[0x4c] = 4;
  CABECALHO[0x50] = 1;
  memcpy(CABECALHO + 0x54, "LOGO_KEY_LEN", 12);
  CABECALHO[0x74] = 4;
}

__attribute__((format(printf, 1, 2))) static void erro(const char *fmt, ...) {
  va_list ap;
  va_start(ap, fmt);
  fprintf(stderr, "nl_logo: ");
  vfprintf(stderr, fmt, ap);
  fprintf(stderr, "\n");
  va_end(ap);
}

static int ler_tudo(const char *arq, unsigned char **buf, long *tam, long max) {
  int fd = open(arq, O_RDONLY);
  if (fd < 0) { erro("nao abri %s (%s)", arq, strerror(errno)); return -1; }
  struct stat st;
  if (fstat(fd, &st) != 0 || !S_ISREG(st.st_mode) || st.st_size <= 0 || st.st_size > max) {
    erro("%s nao e arquivo comum ou tem tamanho fora do limite (%ld)", arq, (long)st.st_size);
    close(fd);
    return -1;
  }
  unsigned char *b = malloc((size_t)st.st_size);
  if (!b) { close(fd); return -1; }
  long lido = 0;
  while (lido < st.st_size) {
    ssize_t r = read(fd, b + lido, (size_t)(st.st_size - lido));
    if (r <= 0) { if (r < 0 && errno == EINTR) continue; free(b); close(fd); erro("leitura curta de %s (%ld)", arq, lido); return -1; }
    lido += r;
  }
  close(fd);
  *buf = b;
  *tam = lido;
  return 0;
}

static int escrever_tudo(int fd, const unsigned char *b, long n) {
  while (n > 0) {
    ssize_t w = write(fd, b, (size_t)n);
    if (w <= 0) { if (w < 0 && errno == EINTR) continue; return -1; }
    b += w;
    n -= w;
  }
  return 0;
}

static int gravar_arquivo(const char *arq, const unsigned char *b, long n) {
  int fd = open(arq, O_WRONLY | O_CREAT | O_TRUNC, 0600);
  if (fd < 0) { erro("nao criei %s (%s)", arq, strerror(errno)); return -1; }
  if (escrever_tudo(fd, b, n) != 0 || fsync(fd) != 0) { close(fd); unlink(arq); erro("falha ao gravar %s (%s)", arq, strerror(errno)); return -1; }
  if (close(fd) != 0) { unlink(arq); return -1; }
  return 0;
}

static int jpeg_ok(const unsigned char *b, long n) {
  return n >= 4 && b[0] == 0xff && b[1] == 0xd8 && b[n - 2] == 0xff && b[n - 1] == 0xd9;
}

static int canto_ler(const char *s, int *x, int *y) {
  int v[2] = {0, 0}, k = 0, d = 0;
  for (const char *p = s; ; p++) {
    if (*p >= '0' && *p <= '9') {
      if (++d > 4) return -1;
      v[k] = v[k] * 10 + (*p - '0');
    } else if (*p == ',' && k == 0 && d > 0) {
      k = 1;
      d = 0;
    } else if (*p == 0 && k == 1 && d > 0) {
      break;
    } else {
      return -1;
    }
  }
  *x = v[0];
  *y = v[1];
  return 0;
}

typedef struct { long x, y; } Pt;

static const char *cantos_motivo(char **arg, Pt *tela, int *reto) {
  int x[4], y[4];
  for (int i = 0; i < 4; i++) {
    if (canto_ler(arg[i], &x[i], &y[i]) != 0) return "formato";
  }
  for (int i = 0; i < 4; i++) {
    if (x[i] > L || y[i] > A) return "fora_da_tela";
  }
  *reto = x[0] == 0 && y[0] == A && x[1] == L && y[1] == A && x[2] == 0 && y[2] == 0 && x[3] == L && y[3] == 0;
  Pt lt = {x[0], A - y[0]}, rt = {x[1], A - y[1]}, lb = {x[2], A - y[2]}, rb = {x[3], A - y[3]};
  Pt q[4] = {lt, rt, rb, lb};
  int64_t area2 = 0;
  for (int i = 0; i < 4; i++) {
    Pt a = q[i], b = q[(i + 1) % 4], c = q[(i + 2) % 4];
    int64_t z = (int64_t)(b.x - a.x) * (c.y - b.y) - (int64_t)(b.y - a.y) * (c.x - b.x);
    if (z <= 0) return "nao_convexo";
    area2 += (int64_t)a.x * b.y - (int64_t)b.x * a.y;
  }
  long cx = L / 2, cy = A / 2;
  if (!(lt.x < cx && lt.y < cy && rt.x > cx && rt.y < cy && rb.x > cx && rb.y > cy && lb.x < cx && lb.y > cy)) return "canto_trocado";
  if (area2 * 100 < (int64_t)2 * L * A * AREA_MIN_PCT) return "area_pequena";
  for (int i = 0; i < 4; i++) tela[i] = (Pt){x[i], A - y[i]};
  return NULL;
}

static int resolve(double m[8][9], double out[8]) {
  const int n = 8;
  for (int c = 0; c < n; c++) {
    int p = c;
    for (int r = c + 1; r < n; r++) {
      if (fabs(m[r][c]) > fabs(m[p][c])) p = r;
    }
    if (p != c) {
      for (int j = 0; j <= n; j++) { double t = m[c][j]; m[c][j] = m[p][j]; m[p][j] = t; }
    }
    if (m[c][c] == 0.0) return -1;
    for (int r = 0; r < n; r++) {
      if (r == c) continue;
      double k = m[r][c] / m[c][c];
      for (int j = 0; j <= n; j++) m[r][j] = m[r][j] - k * m[c][j];
    }
  }
  for (int i = 0; i < n; i++) {
    out[i] = m[i][n] / m[i][i];
    if (!isfinite(out[i])) return -1;
  }
  return 0;
}

static int coeficientes(const Pt *tela, double coef[8]) {
  Pt lt = tela[0], rt = tela[1], lb = tela[2], rb = tela[3];
  Pt destino[4] = {lt, rt, rb, lb};
  long origem[4][2] = {{0, 0}, {L, 0}, {L, A}, {0, A}};
  double m[8][9];
  for (int i = 0; i < 4; i++) {
    long xd = destino[i].x, yd = destino[i].y, xo = origem[i][0], yo = origem[i][1];
    double *a = m[2 * i], *b = m[2 * i + 1];
    a[0] = (double)xd; a[1] = (double)yd; a[2] = 1; a[3] = 0; a[4] = 0; a[5] = 0;
    a[6] = (double)(-xo * xd); a[7] = (double)(-xo * yd); a[8] = (double)xo;
    b[0] = 0; b[1] = 0; b[2] = 0; b[3] = (double)xd; b[4] = (double)yd; b[5] = 1;
    b[6] = (double)(-yo * xd); b[7] = (double)(-yo * yd); b[8] = (double)yo;
  }
  return resolve(m, coef);
}

#define BICUBIC(v, v1, v2, v3, v4, d)        \
  {                                          \
    double p1 = v2;                          \
    double p2 = -v1 + v3;                    \
    double p3 = 2 * (v1 - v2) + v3 - v4;     \
    double p4 = -v1 + v2 - v3 + v4;          \
    v = p1 + (d) * (p2 + (d) * (p3 + (d) * p4)); \
  }

static int clip(int v, int max) { return v < 0 ? 0 : (v < max ? v : max - 1); }

static void bicubico(const unsigned char *src, double xin, double yin, unsigned char *out) {
  if (xin < 0.0 || xin >= L || yin < 0.0 || yin >= A) {
    out[0] = out[1] = out[2] = 0;
    return;
  }
  xin -= 0.5;
  yin -= 0.5;
  int x = (int)floor(xin);
  int y = (int)floor(yin);
  double dx = xin - x;
  double dy = yin - y;
  x--;
  y--;
  int x0 = clip(x + 0, L) * 3, x1 = clip(x + 1, L) * 3, x2 = clip(x + 2, L) * 3, x3 = clip(x + 3, L) * 3;
  for (int b = 0; b < 3; b++) {
    double v1, v2, v3, v4;
    const unsigned char *in = src + (size_t)clip(y, A) * L * 3 + b;
    BICUBIC(v1, in[x0], in[x1], in[x2], in[x3], dx);
    if (y + 1 >= 0 && y + 1 < A) {
      in = src + (size_t)(y + 1) * L * 3 + b;
      BICUBIC(v2, in[x0], in[x1], in[x2], in[x3], dx);
    } else {
      v2 = v1;
    }
    if (y + 2 >= 0 && y + 2 < A) {
      in = src + (size_t)(y + 2) * L * 3 + b;
      BICUBIC(v3, in[x0], in[x1], in[x2], in[x3], dx);
    } else {
      v3 = v2;
    }
    if (y + 3 >= 0 && y + 3 < A) {
      in = src + (size_t)(y + 3) * L * 3 + b;
      BICUBIC(v4, in[x0], in[x1], in[x2], in[x3], dx);
    } else {
      v4 = v3;
    }
    BICUBIC(v1, v1, v2, v3, v4, dy);
    if (v1 <= 0.0) out[b] = 0;
    else if (v1 >= 255.0) out[b] = 255;
    else out[b] = (unsigned char)v1;
  }
}

static void distorcer(const unsigned char *src, const double a[8], unsigned char *dst) {
  for (int y = 0; y < A; y++) {
    for (int x = 0; x < L; x++) {
      double xin = x + 0.5;
      double yin = y + 0.5;
      double xo = (a[0] * xin + a[1] * yin + a[2]) / (a[6] * xin + a[7] * yin + 1);
      double yo = (a[3] * xin + a[4] * yin + a[5]) / (a[6] * xin + a[7] * yin + 1);
      bicubico(src, xo, yo, dst + ((size_t)y * L + x) * 3);
    }
  }
}

typedef struct { unsigned char *b; long n, cap; int falhou; } Saida;

static void juntar(void *ctx, void *dados, int n) {
  Saida *s = ctx;
  if (s->falhou || n < 0) { s->falhou = 1; return; }
  if (s->n + n > s->cap) {
    long cap = s->cap ? s->cap * 2 : (1L << 18);
    while (cap < s->n + n) cap *= 2;
    if (cap > 4 * MAX_JPEG) { s->falhou = 1; return; }
    unsigned char *nb = realloc(s->b, (size_t)cap);
    if (!nb) { s->falhou = 1; return; }
    s->b = nb;
    s->cap = cap;
  }
  memcpy(s->b + s->n, dados, (size_t)n);
  s->n += n;
}

/* O stb_image_write poe as 2 tabelas de quantizacao num DQT so e as 4 de Huffman num DHT so. Os bytes das
   tabelas sao os mesmos do Pillow (libjpeg), que escreve um segmento por tabela, e e esse arranjo que o carregador
   ja leu (logo de fabrica, arte reta e o logo do pfl7560-marca.sh). Reescreve o cabecalho com um segmento por
   tabela; do SOS em diante copia sem tocar. Qualquer coisa fora do esperado: falha (nao grava). */
static int emitir(unsigned char *o, long *k, long cap, const unsigned char *b, long n) {
  if (n < 0 || *k + n > cap) return -1;
  memcpy(o + *k, b, (size_t)n);
  *k += n;
  return 0;
}

static int emitir_tabela(unsigned char *o, long *k, long cap, unsigned char m, const unsigned char *t, long tl) {
  unsigned char c[4] = {0xff, m, (unsigned char)((tl + 2) >> 8), (unsigned char)((tl + 2) & 0xff)};
  if (tl + 2 > 0xffff) return -1;
  return emitir(o, k, cap, c, 4) == 0 && emitir(o, k, cap, t, tl) == 0 ? 0 : -1;
}

static int separar_tabelas(Saida *s) {
  const unsigned char *b = s->b;
  long n = s->n, cap = n + 1024, k = 0, pos = 2;
  if (n < 4 || b[0] != 0xff || b[1] != 0xd8) return -1;
  unsigned char *o = malloc((size_t)cap);
  if (!o) return -1;
  if (emitir(o, &k, cap, b, 2) != 0) goto falha;
  for (;;) {
    if (pos + 4 > n || b[pos] != 0xff) goto falha;
    unsigned char m = b[pos + 1];
    long len = (long)b[pos + 2] << 8 | b[pos + 3];
    if (len < 2 || pos + 2 + len > n) goto falha;
    long p = pos + 4, fim = pos + 2 + len;
    if (m == 0xda) {
      if (emitir(o, &k, cap, b + pos, n - pos) != 0) goto falha;
      break;
    } else if (m == 0xdb) {
      while (p < fim) {
        long tl = 1 + ((b[p] >> 4) ? 128 : 64);
        if (p + tl > fim || emitir_tabela(o, &k, cap, m, b + p, tl) != 0) goto falha;
        p += tl;
      }
    } else if (m == 0xc4) {
      while (p < fim) {
        if (p + 17 > fim) goto falha;
        long tl = 17;
        for (int i = 1; i <= 16; i++) tl += b[p + i];
        if (p + tl > fim || emitir_tabela(o, &k, cap, m, b + p, tl) != 0) goto falha;
        p += tl;
      }
    } else if ((m >= 0xe0 && m <= 0xef) || m == 0xc0 || m == 0xfe) {
      if (emitir(o, &k, cap, b + pos, 2 + len) != 0) goto falha;
    } else {
      goto falha;
    }
    pos = fim;
  }
  free(s->b);
  s->b = o;
  s->n = k;
  s->cap = cap;
  return 0;
falha:
  free(o);
  return -1;
}

static int termina_com(const char *s, const char *fim) {
  size_t a = strlen(s), b = strlen(fim);
  return a >= b && strcmp(s + a - b, fim) == 0;
}

static int cmd_cantos(char **arg) {
  Pt tela[4];
  int reto = 0;
  const char *m = cantos_motivo(arg, tela, &reto);
  if (m) { printf("%s\n", m); return 3; }
  double c[8];
  if (coeficientes(tela, c) != 0) { printf("nao_convexo\n"); return 3; }
  printf("ok\n");
  return 0;
}

static int cmd_gerar(const char *entrada, char **arg, const char *saida) {
  Pt tela[4];
  int reto = 0;
  const char *m = cantos_motivo(arg, tela, &reto);
  if (m) { printf("%s\n", m); return 3; }
  double coef[8];
  if (coeficientes(tela, coef) != 0) { printf("nao_convexo\n"); return 3; }
  unsigned char *arq;
  long tam;
  if (ler_tudo(entrada, &arq, &tam, MAX_ENTRADA) != 0) return 1;
  int w = 0, h = 0, c = 0;
  unsigned char *img = NULL;
  long pc = (long)sizeof PPM_CAB - 1;
  if (tam == pc + (long)L * A * 3 && memcmp(arq, PPM_CAB, (size_t)pc) == 0) {
    img = malloc((size_t)L * A * 3);
    if (img) { memcpy(img, arq + pc, (size_t)L * A * 3); w = L; h = A; }
  } else if (jpeg_ok(arq, tam)) {
    img = stbi_load_from_memory(arq, (int)tam, &w, &h, &c, 3);
  }
  if (!img || w != L || h != A) {
    erro("%s nao e um JPEG (ou PPM P6) de 1920x1080 (%dx%d)", entrada, w, h);
    free(img);
    free(arq);
    return 1;
  }
  int ppm = termina_com(saida, ".ppm");
  int r = 1;
  if (reto && !ppm && jpeg_ok(arq, tam)) {
    if (tam > MAX_JPEG) erro("arte reta com %ld bytes, acima do limite", tam);
    else r = gravar_arquivo(saida, arq, tam) == 0 ? 0 : 1;
    free(img);
    free(arq);
    return r;
  }
  free(arq);
  unsigned char *dst = malloc((size_t)L * A * 3);
  if (!dst) { free(img); return 1; }
  distorcer(img, coef, dst);
  free(img);
  if (ppm) {
    char cab[32];
    int n = snprintf(cab, sizeof cab, "P6\n%d %d\n255\n", L, A);
    unsigned char *b = malloc((size_t)n + (size_t)L * A * 3);
    if (b) {
      memcpy(b, cab, (size_t)n);
      memcpy(b + n, dst, (size_t)L * A * 3);
      r = gravar_arquivo(saida, b, n + (long)L * A * 3) == 0 ? 0 : 1;
      free(b);
    }
    free(dst);
    return r;
  }
  Saida s = {0};
  int ok = stbi_write_jpg_to_func(juntar, &s, L, A, 3, dst, QUALIDADE);
  free(dst);
  if (!ok || s.falhou || !jpeg_ok(s.b, s.n)) {
    erro("falha ao codificar o JPEG (%ld bytes)", s.n);
  } else if (separar_tabelas(&s) != 0 || !jpeg_ok(s.b, s.n)) {
    erro("cabecalho do JPEG fora do esperado (DQT/DHT)");
  } else if (s.n > MAX_JPEG) {
    erro("JPEG gerado com %ld bytes, acima do limite", s.n);
  } else {
    r = gravar_arquivo(saida, s.b, s.n) == 0 ? 0 : 1;
  }
  free(s.b);
  return r;
}

static long cabecalho(const char *arq) {
  int fd = open(arq, O_RDONLY);
  if (fd < 0) { erro("nao abri %s (%s)", arq, strerror(errno)); return -1; }
  off_t fim = lseek(fd, 0, SEEK_END);
  if (fim != (off_t)TAM_PART) { erro("%s tem %ld bytes, esperado 41943040", arq, (long)fim); close(fd); return -1; }
  unsigned char h[JPEG_OFF + 2];
  if (pread(fd, h, sizeof h, 0) != (ssize_t)sizeof h) { erro("leitura curta do cabecalho de %s", arq); close(fd); return -1; }
  if (memcmp(h, CABECALHO, sizeof CABECALHO) != 0) { erro("cabecalho LOGO_TABLE de %s nao e o conhecido", arq); close(fd); return -1; }
  for (long i = KEYLEN_OFF + 4; i < JPEG_OFF; i++) {
    if (h[i] != 0) { erro("%s tem byte nao nulo no cabecalho (posicao %ld)", arq, i); close(fd); return -1; }
  }
  long n = (long)h[KEYLEN_OFF] | (long)h[KEYLEN_OFF + 1] << 8 | (long)h[KEYLEN_OFF + 2] << 16 | (long)h[KEYLEN_OFF + 3] << 24;
  if (n < 4 || n > TAM_PART - JPEG_OFF) { erro("%s: LOGO_KEY_LEN=%ld fora da faixa", arq, n); close(fd); return -1; }
  unsigned char e[2];
  if (h[JPEG_OFF] != 0xff || h[JPEG_OFF + 1] != 0xd8 || pread(fd, e, 2, JPEG_OFF + n - 2) != 2 || e[0] != 0xff || e[1] != 0xd9) {
    erro("%s: o JPEG no byte 8192 nao comeca em FFD8 ou nao termina em FFD9 no LOGO_KEY_LEN (%ld)", arq, n);
    close(fd);
    return -1;
  }
  close(fd);
  return n;
}

static int cmd_extrair(const char *img, const char *saida) {
  long n = cabecalho(img);
  if (n < 0) return 1;
  if (n > MAX_ENTRADA) { erro("JPEG de %s grande demais (%ld)", img, n); return 1; }
  int fd = open(img, O_RDONLY);
  if (fd < 0) return 1;
  unsigned char *b = malloc((size_t)n);
  int r = 1;
  if (b && pread(fd, b, (size_t)n, JPEG_OFF) == (ssize_t)n && jpeg_ok(b, n)) r = gravar_arquivo(saida, b, n) == 0 ? 0 : 1;
  else erro("nao li o JPEG de %s (%ld)", img, n);
  free(b);
  close(fd);
  return r;
}

static int cmd_montar(const char *base, const char *novo, const char *saida, const char *keylen) {
  if (cabecalho(base) < 0) return 1;
  unsigned char *j;
  long jn;
  if (ler_tudo(novo, &j, &jn, MAX_JPEG) != 0) return 1;
  if (!jpeg_ok(j, jn) || JPEG_OFF + jn > TAM_PART) { erro("%s nao e um JPEG com SOI/EOI que caiba (%ld)", novo, jn); free(j); return 1; }
  unsigned char k[4] = {(unsigned char)(jn & 0xff), (unsigned char)(jn >> 8 & 0xff), (unsigned char)(jn >> 16 & 0xff), (unsigned char)(jn >> 24 & 0xff)};
  int in = open(base, O_RDONLY);
  int out = open(saida, O_WRONLY | O_CREAT | O_TRUNC, 0600);
  int r = 1;
  if (in >= 0 && out >= 0) {
    static unsigned char buf[1 << 16];
    long pos = 0;
    r = 0;
    while (pos < TAM_PART) {
      long q = TAM_PART - pos < (long)sizeof buf ? TAM_PART - pos : (long)sizeof buf;
      if (pread(in, buf, (size_t)q, pos) != (ssize_t)q) { r = 1; break; }
      for (long i = 0; i < q; i++) {
        long p = pos + i;
        if (p >= KEYLEN_OFF && p < KEYLEN_OFF + 4) buf[i] = k[p - KEYLEN_OFF];
        else if (p >= JPEG_OFF && p < JPEG_OFF + jn) buf[i] = j[p - JPEG_OFF];
      }
      if (escrever_tudo(out, buf, q) != 0) { r = 1; break; }
      pos += q;
    }
    if (r == 0 && fsync(out) != 0) r = 1;
  }
  if (in >= 0) close(in);
  if (out >= 0 && close(out) != 0) r = 1;
  free(j);
  if (r == 0) r = gravar_arquivo(keylen, k, 4) == 0 ? 0 : 1;
  if (r == 0 && cabecalho(saida) != jn) r = 1;
  if (r != 0) { unlink(saida); unlink(keylen); erro("nao montei %s", saida); }
  return r;
}

static int uso(void) {
  fprintf(stderr,
          "uso: nl_logo cantos <lt> <rt> <lb> <rb>\n"
          "     nl_logo gerar <arte_reta.jpg> <lt> <rt> <lb> <rb> <saida.jpg|saida.ppm>\n"
          "     nl_logo cabecalho <particao|imagem>\n"
          "     nl_logo extrair <particao|imagem> <saida.jpg>\n"
          "     nl_logo montar <base.img> <novo.jpg> <saida.img> <keylen.bin>\n");
  return 2;
}

int main(int argc, char **argv) {
  cabecalho_conhecido();
  if (argc == 6 && strcmp(argv[1], "cantos") == 0) return cmd_cantos(argv + 2);
  if (argc == 8 && strcmp(argv[1], "gerar") == 0) return cmd_gerar(argv[2], argv + 3, argv[7]);
  if (argc == 3 && strcmp(argv[1], "cabecalho") == 0) {
    long n = cabecalho(argv[2]);
    if (n < 0) return 1;
    printf("%ld\n", n);
    return 0;
  }
  if (argc == 4 && strcmp(argv[1], "extrair") == 0) return cmd_extrair(argv[2], argv[3]);
  if (argc == 6 && strcmp(argv[1], "montar") == 0) return cmd_montar(argv[2], argv[3], argv[4], argv[5]);
  return uso();
}
