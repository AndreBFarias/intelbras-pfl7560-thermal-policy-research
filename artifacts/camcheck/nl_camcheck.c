/*
 * nl_camcheck - sonda e captura da camera interna (UVC) do PFL7560 via V4L2.
 *
 * Etapa E1/E5 do bloco 5 (docs/research/41). SOMENTE LEITURA em relacao a
 * camera: nao escreve controle nenhum (exposicao, balanco de branco ficam
 * como estao). Uso, com root no aparelho:
 *
 *   nl_camcheck info [/dev/video0]
 *       driver, formatos, tamanhos e controles (com valor atual)
 *   nl_camcheck grab /dev/video0 MJPG|YUYV <larg> <alt> <saida> [descarte]
 *       captura 1 quadro depois de descartar N (padrao 10, para a exposicao
 *       automatica assentar) e grava os bytes crus em <saida>
 *       (MJPG = um .jpg valido; YUYV = cru, converter no PC)
 *
 * Bloco 7 (docs/sprints/2026-10-30-bloco-7-cor-automatica.md): analise da
 * escada de cinzas projetada, para o modo automatico do kit de cor.
 *
 *   nl_camcheck faixas <dev> <N> <saida.txt> [descarte]
 *       captura UM quadro YUYV (1280x720; senao 640x480; senao o menor
 *       YUYV listado), faz o perfil de linhas, e exige EXATAMENTE N faixas
 *       claras. Grava uma linha "ini fim" por faixa (linhas do quadro, fim
 *       exclusivo). Sai com 0 se achou N, 3 se nao achou (diz quantas achou).
 *   nl_camcheck niveis <dev> <faixas.txt> [descarte]
 *       captura um quadro e imprime a media do miolo de cada faixa (uma por
 *       linha) e, na ultima linha, "inv_cresc=X inv_decresc=Y": quedas e
 *       subidas entre faixas vizinhas maiores que 3% da amplitude.
 *   No lugar de <dev>, "arquivo:<caminho.yuyv>:<L>:<A>" le o quadro do disco
 *   (sem V4L2): serve ao harness do PC (tests/test-camcheck.sh).
 *
 * Compilar (NDK r27c):
 *   armv7a-linux-androideabi24-clang -O2 -Wall -o nl_camcheck nl_camcheck.c
 * No PC (harness): cc -O2 -Wall -o nl_camcheck nl_camcheck.c
 */
#include <errno.h>
#include <fcntl.h>
#include <linux/videodev2.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <unistd.h>

#define NBUF 4

static int xioctl(int fd, unsigned long req, void *arg) {
  int r;
  do r = ioctl(fd, req, arg); while (r == -1 && errno == EINTR);
  return r;
}

static void fourcc(unsigned v, char out[5]) {
  out[0] = v & 0xff; out[1] = (v >> 8) & 0xff;
  out[2] = (v >> 16) & 0xff; out[3] = (v >> 24) & 0xff; out[4] = 0;
}

static int info(const char *dev) {
  int fd = open(dev, O_RDWR);
  if (fd < 0) { fprintf(stderr, "open %s: %s\n", dev, strerror(errno)); return 1; }

  struct v4l2_capability cap;
  memset(&cap, 0, sizeof cap);
  if (xioctl(fd, VIDIOC_QUERYCAP, &cap) < 0) { perror("QUERYCAP"); close(fd); return 1; }
  printf("driver=%s card=%s bus=%s caps=0x%08x\n", cap.driver, cap.card, cap.bus_info, cap.capabilities);

  struct v4l2_fmtdesc fd_;
  memset(&fd_, 0, sizeof fd_);
  fd_.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
  for (fd_.index = 0; xioctl(fd, VIDIOC_ENUM_FMT, &fd_) == 0; fd_.index++) {
    char cc[5]; fourcc(fd_.pixelformat, cc);
    printf("formato %s (%s)\n", cc, fd_.description);
    struct v4l2_frmsizeenum fs;
    memset(&fs, 0, sizeof fs);
    fs.pixel_format = fd_.pixelformat;
    for (fs.index = 0; xioctl(fd, VIDIOC_ENUM_FRAMESIZES, &fs) == 0; fs.index++)
      if (fs.type == V4L2_FRMSIZE_TYPE_DISCRETE)
        printf("  %ux%u\n", fs.discrete.width, fs.discrete.height);
  }

  struct v4l2_queryctrl qc;
  memset(&qc, 0, sizeof qc);
  qc.id = V4L2_CTRL_FLAG_NEXT_CTRL;
  while (xioctl(fd, VIDIOC_QUERYCTRL, &qc) == 0) {
    if (!(qc.flags & V4L2_CTRL_FLAG_DISABLED)) {
      struct v4l2_control c = { .id = qc.id };
      int ok = xioctl(fd, VIDIOC_G_CTRL, &c) == 0;
      printf("controle 0x%08x %-32s min=%d max=%d def=%d atual=%s%d\n", qc.id, qc.name,
             qc.minimum, qc.maximum, qc.default_value, ok ? "" : "?", ok ? c.value : 0);
    }
    qc.id |= V4L2_CTRL_FLAG_NEXT_CTRL;
  }
  close(fd);
  return 0;
}

static int grab(const char *dev, const char *fmt, int w, int h, const char *out, int skip) {
  int fd = open(dev, O_RDWR);
  if (fd < 0) { fprintf(stderr, "open %s: %s\n", dev, strerror(errno)); return 1; }

  struct v4l2_format f;
  memset(&f, 0, sizeof f);
  f.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
  f.fmt.pix.width = w; f.fmt.pix.height = h;
  f.fmt.pix.pixelformat = strcmp(fmt, "YUYV") == 0 ? V4L2_PIX_FMT_YUYV : V4L2_PIX_FMT_MJPEG;
  f.fmt.pix.field = V4L2_FIELD_ANY;
  if (xioctl(fd, VIDIOC_S_FMT, &f) < 0) { perror("S_FMT"); close(fd); return 1; }
  char cc[5]; fourcc(f.fmt.pix.pixelformat, cc);
  printf("negociado %s %ux%u\n", cc, f.fmt.pix.width, f.fmt.pix.height);

  struct v4l2_requestbuffers rb;
  memset(&rb, 0, sizeof rb);
  rb.count = NBUF; rb.type = V4L2_BUF_TYPE_VIDEO_CAPTURE; rb.memory = V4L2_MEMORY_MMAP;
  if (xioctl(fd, VIDIOC_REQBUFS, &rb) < 0) { perror("REQBUFS"); close(fd); return 1; }
  if (rb.count == 0) { fprintf(stderr, "REQBUFS: o driver nao deu nenhum buffer\n"); close(fd); return 1; }

  void *mem[NBUF]; size_t len[NBUF];
  if (rb.count > NBUF) rb.count = NBUF;
  for (unsigned i = 0; i < rb.count; i++) {
    struct v4l2_buffer b;
    memset(&b, 0, sizeof b);
    b.type = rb.type; b.memory = rb.memory; b.index = i;
    if (xioctl(fd, VIDIOC_QUERYBUF, &b) < 0) { perror("QUERYBUF"); close(fd); return 1; }
    len[i] = b.length;
    mem[i] = mmap(NULL, b.length, PROT_READ | PROT_WRITE, MAP_SHARED, fd, b.m.offset);
    if (mem[i] == MAP_FAILED) { perror("mmap"); close(fd); return 1; }
    if (xioctl(fd, VIDIOC_QBUF, &b) < 0) { perror("QBUF"); close(fd); return 1; }
  }

  enum v4l2_buf_type t = V4L2_BUF_TYPE_VIDEO_CAPTURE;
  if (xioctl(fd, VIDIOC_STREAMON, &t) < 0) { perror("STREAMON"); close(fd); return 1; }

  int rc = 1;
  for (int n = 0; n <= skip; n++) {
    struct v4l2_buffer b;
    memset(&b, 0, sizeof b);
    b.type = rb.type; b.memory = rb.memory;
    if (xioctl(fd, VIDIOC_DQBUF, &b) < 0) { perror("DQBUF"); break; }
    if (n == skip) {
      FILE *o = fopen(out, "wb");
      if (!o) { perror(out); break; }
      int ok = fwrite(mem[b.index], 1, b.bytesused, o) == b.bytesused;
      if (fclose(o) != 0) ok = 0;
      if (!ok) { fprintf(stderr, "%s: gravacao incompleta\n", out); break; }
      printf("gravado %s (%u bytes)\n", out, b.bytesused);
      rc = 0;
    }
    if (xioctl(fd, VIDIOC_QBUF, &b) < 0) { perror("QBUF"); break; }
  }

  xioctl(fd, VIDIOC_STREAMOFF, &t);
  for (unsigned i = 0; i < rb.count; i++) munmap(mem[i], len[i]);
  close(fd);
  return rc;
}

/* ---- bloco 7: analise de faixas (so le o quadro; nada de S_CTRL) ------------ */

#define MAXFAIXAS 64
/* perfil de linhas nas colunas 47 a 53% da largura. Faixa larga (35 a 65%) falhou
 * no aparelho (bloco 8): a imagem projetada sai inclinada para a camera e, numa
 * janela larga, cada faixa escorre sobre a vizinha e os vaos nao escurecem. */
#define COL_INI_PCT 47
#define COL_FIM_PCT 53
#define MARGEM 0.03      /* queda/subida que conta como inversao: 3% da amplitude */
#define LADO_MIN 16      /* quadro menor que isso nao tem colunas para o perfil */
#define LADO_MAX 4096    /* e maior que isso nao e da camera interna (e estoura size_t de 32 bits) */

struct quadro { unsigned char *dados; int larg, alt, stride; };

/* dimensoes que o perfil aguenta: colunas c0 < c1 e linha inteira dentro do stride */
static int dimensoes_ok(int larg, int alt, int stride) {
  if (larg < LADO_MIN || alt < LADO_MIN || larg > LADO_MAX || alt > LADO_MAX || stride < larg * 2) {
    fprintf(stderr, "quadro com dimensoes invalidas: %dx%d, %d bytes por linha\n", larg, alt, stride);
    return 0;
  }
  return 1;
}

/* Captura UM quadro YUYV do V4L2 (descarta 'skip'). Tamanho: 1280x720 se o
 * driver o oferece (vaos entre faixas com o dobro de linhas), senao 640x480,
 * senao o menor YUYV listado. Devolve 0 e preenche q. */
static int captura_yuyv(const char *dev, int skip, struct quadro *q) {
  int fd = open(dev, O_RDWR);
  if (fd < 0) { fprintf(stderr, "open %s: %s\n", dev, strerror(errno)); return 1; }

  unsigned w = 0, h = 0, tem_hd = 0, tem_vga = 0;
  struct v4l2_frmsizeenum fs;
  memset(&fs, 0, sizeof fs);
  fs.pixel_format = V4L2_PIX_FMT_YUYV;
  for (fs.index = 0; xioctl(fd, VIDIOC_ENUM_FRAMESIZES, &fs) == 0; fs.index++) {
    if (fs.type != V4L2_FRMSIZE_TYPE_DISCRETE) continue;
    unsigned fw = fs.discrete.width, fh = fs.discrete.height;
    if (fw == 1280 && fh == 720) tem_hd = 1;
    if (fw == 640 && fh == 480) tem_vga = 1;
    if (w == 0 || fw * fh < w * h) { w = fw; h = fh; }
  }
  if (tem_hd) { w = 1280; h = 720; }
  else if (tem_vga || w == 0) { w = 640; h = 480; }

  struct v4l2_format f;
  memset(&f, 0, sizeof f);
  f.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
  f.fmt.pix.width = w; f.fmt.pix.height = h;
  f.fmt.pix.pixelformat = V4L2_PIX_FMT_YUYV;
  f.fmt.pix.field = V4L2_FIELD_ANY;
  if (xioctl(fd, VIDIOC_S_FMT, &f) < 0) { perror("S_FMT"); close(fd); return 1; }
  if (f.fmt.pix.pixelformat != V4L2_PIX_FMT_YUYV) {
    fprintf(stderr, "driver nao entregou YUYV\n"); close(fd); return 1;
  }
  int stride = f.fmt.pix.bytesperline ? (int)f.fmt.pix.bytesperline : (int)f.fmt.pix.width * 2;
  if (!dimensoes_ok((int)f.fmt.pix.width, (int)f.fmt.pix.height, stride)) { close(fd); return 1; }

  struct v4l2_requestbuffers rb;
  memset(&rb, 0, sizeof rb);
  rb.count = NBUF; rb.type = V4L2_BUF_TYPE_VIDEO_CAPTURE; rb.memory = V4L2_MEMORY_MMAP;
  if (xioctl(fd, VIDIOC_REQBUFS, &rb) < 0) { perror("REQBUFS"); close(fd); return 1; }

  if (rb.count == 0) { fprintf(stderr, "REQBUFS: o driver nao deu nenhum buffer\n"); close(fd); return 1; }

  void *mem[NBUF]; size_t len[NBUF];
  if (rb.count > NBUF) rb.count = NBUF;
  for (unsigned i = 0; i < rb.count; i++) {
    struct v4l2_buffer b;
    memset(&b, 0, sizeof b);
    b.type = rb.type; b.memory = rb.memory; b.index = i;
    if (xioctl(fd, VIDIOC_QUERYBUF, &b) < 0) { perror("QUERYBUF"); close(fd); return 1; }
    len[i] = b.length;
    mem[i] = mmap(NULL, b.length, PROT_READ | PROT_WRITE, MAP_SHARED, fd, b.m.offset);
    if (mem[i] == MAP_FAILED) { perror("mmap"); close(fd); return 1; }
    if (xioctl(fd, VIDIOC_QBUF, &b) < 0) { perror("QBUF"); close(fd); return 1; }
  }

  enum v4l2_buf_type t = V4L2_BUF_TYPE_VIDEO_CAPTURE;
  if (xioctl(fd, VIDIOC_STREAMON, &t) < 0) { perror("STREAMON"); close(fd); return 1; }

  int rc = 1;
  for (int n = 0; n <= skip; n++) {
    struct v4l2_buffer b;
    memset(&b, 0, sizeof b);
    b.type = rb.type; b.memory = rb.memory;
    if (xioctl(fd, VIDIOC_DQBUF, &b) < 0) { perror("DQBUF"); break; }
    if (n == skip) {
      size_t esperado = (size_t)stride * f.fmt.pix.height;
      if (b.flags & V4L2_BUF_FLAG_ERROR) {
        fprintf(stderr, "quadro marcado com erro pelo driver\n");
        break;
      }
      if (b.bytesused < esperado || b.length < esperado) {
        fprintf(stderr, "quadro curto: %u bytes, esperado %zu\n", b.bytesused, esperado);
        break;
      }
      q->dados = malloc(esperado);
      if (!q->dados) { perror("malloc"); break; }
      memcpy(q->dados, mem[b.index], esperado);
      q->larg = f.fmt.pix.width; q->alt = f.fmt.pix.height; q->stride = stride;
      rc = 0;
    }
    if (xioctl(fd, VIDIOC_QBUF, &b) < 0) { perror("QBUF"); break; }
  }

  xioctl(fd, VIDIOC_STREAMOFF, &t);
  for (unsigned i = 0; i < rb.count; i++) munmap(mem[i], len[i]);
  close(fd);
  return rc;
}

/* Le um quadro YUYV cru do disco: "arquivo:<caminho>:<L>:<A>". */
static int ler_arquivo(const char *spec, struct quadro *q) {
  char *c = strdup(spec + 8);
  if (!c) return 1;
  char *p2 = strrchr(c, ':');
  char *p1 = p2 ? (*p2 = 0, strrchr(c, ':')) : NULL;
  if (!p1) { fprintf(stderr, "uso: arquivo:<caminho.yuyv>:<L>:<A>\n"); free(c); return 1; }
  *p1 = 0;
  int larg = atoi(p1 + 1), alt = atoi(p2 + 1);
  if (!dimensoes_ok(larg, alt, larg > LADO_MAX ? 0 : larg * 2)) { free(c); return 1; }
  FILE *f = fopen(c, "rb");
  if (!f) { fprintf(stderr, "open %s: %s\n", c, strerror(errno)); free(c); return 1; }
  size_t n = (size_t)larg * 2 * alt;
  q->dados = malloc(n);
  /* o arquivo tem de ter EXATAMENTE L*A*2 bytes: nem menos (curto) nem mais (outro tamanho) */
  if (!q->dados || fread(q->dados, 1, n, f) != n || fgetc(f) != EOF) {
    fprintf(stderr, "%s: tamanho diferente de %zu bytes (YUYV %dx%d)\n", c, n, larg, alt);
    fclose(f); free(c); free(q->dados); q->dados = NULL; return 1;
  }
  fclose(f); free(c);
  q->larg = larg; q->alt = alt; q->stride = larg * 2;
  return 0;
}

/* dev = /dev/videoN (captura) ou arquivo:... (disco) */
static int obter_quadro(const char *dev, int skip, struct quadro *q) {
  if (strncmp(dev, "arquivo:", 8) == 0) return ler_arquivo(dev, q);
  return captura_yuyv(dev, skip, q);
}

/* media da luma (bytes pares do YUYV) das colunas [c0,c1) da linha y */
static double media_linha(const struct quadro *q, int y, int c0, int c1) {
  const unsigned char *l = q->dados + (size_t)y * q->stride;
  long soma = 0;
  for (int x = c0; x < c1; x++) soma += l[2 * x];
  return (double)soma / (c1 - c0);
}

static int faixas_cmd(const char *dev, int n, const char *saida, int skip) {
  struct quadro q = {0};
  int rc = obter_quadro(dev, skip, &q);
  if (rc) return 1;
  int c0 = q.larg * COL_INI_PCT / 100, c1 = q.larg * COL_FIM_PCT / 100;
  double *perfil = malloc(sizeof(double) * q.alt);
  if (!perfil) { free(q.dados); return 1; }
  double mn = 1e9, mx = -1e9;
  for (int y = 0; y < q.alt; y++) {
    perfil[y] = media_linha(&q, y, c0, c1);
    if (perfil[y] < mn) mn = perfil[y];
    if (perfil[y] > mx) mx = perfil[y];
  }
  double lim = (mn + mx) / 2;
  int ini[MAXFAIXAS], fim[MAXFAIXAS], achou = 0, dentro = 0;
  for (int y = 0; y <= q.alt; y++) {
    int acima = y < q.alt && perfil[y] > lim;
    if (acima && !dentro) { dentro = 1; if (achou < MAXFAIXAS) ini[achou] = y; }
    if (!acima && dentro) { dentro = 0; if (achou < MAXFAIXAS) fim[achou] = y; achou++; }
  }
  free(perfil); free(q.dados);
  printf("faixas achadas: %d (esperadas %d)\n", achou, n);
  if (achou != n || n > MAXFAIXAS) return 3;
  FILE *o = fopen(saida, "w");
  if (!o) { perror(saida); return 1; }
  for (int i = 0; i < n; i++) fprintf(o, "%d %d\n", ini[i], fim[i]);
  if (fclose(o) != 0) { perror(saida); return 1; }
  return 0;
}

static int niveis_cmd(const char *dev, const char *arq, int skip) {
  int ini[MAXFAIXAS], fim[MAXFAIXAS], n = 0;
  FILE *f = fopen(arq, "r");
  if (!f) { fprintf(stderr, "open %s: %s\n", arq, strerror(errno)); return 1; }
  while (n < MAXFAIXAS && fscanf(f, "%d %d", &ini[n], &fim[n]) == 2) n++;
  fclose(f);
  if (n < 2) { fprintf(stderr, "%s: faixas insuficientes (%d)\n", arq, n); return 1; }

  struct quadro q = {0};
  if (obter_quadro(dev, skip, &q)) return 1;
  int c0 = q.larg * COL_INI_PCT / 100, c1 = q.larg * COL_FIM_PCT / 100;
  double nivel[MAXFAIXAS];
  for (int i = 0; i < n; i++) {
    int comp = fim[i] - ini[i], borda = comp / 4;
    int y0 = ini[i] + borda, y1 = fim[i] - borda;
    if (ini[i] < 0 || fim[i] > q.alt || comp < 1) {
      fprintf(stderr, "faixa %d fora do quadro (%d..%d, altura %d)\n", i, ini[i], fim[i], q.alt);
      free(q.dados); return 1;
    }
    if (y1 <= y0) { y0 = ini[i]; y1 = fim[i]; }
    double soma = 0;
    for (int y = y0; y < y1; y++) soma += media_linha(&q, y, c0, c1);
    nivel[i] = soma / (y1 - y0);
  }
  free(q.dados);
  double mn = nivel[0], mx = nivel[0];
  for (int i = 1; i < n; i++) { if (nivel[i] < mn) mn = nivel[i]; if (nivel[i] > mx) mx = nivel[i]; }
  double margem = MARGEM * (mx - mn);
  int cresc = 0, decresc = 0;
  for (int i = 0; i < n; i++) printf("%.0f\n", nivel[i]);
  for (int i = 1; i < n; i++) {
    if (nivel[i - 1] - nivel[i] > margem) cresc++;      /* queda: fere a ordem crescente */
    if (nivel[i] - nivel[i - 1] > margem) decresc++;    /* subida: fere a ordem decrescente */
  }
  printf("inv_cresc=%d inv_decresc=%d\n", cresc, decresc);
  return 0;
}

/* ---- bloco 9A: geometria da tela de calibracao (so le o quadro) --------------- */

/* tres janelas de colunas: esquerda, centro (a mesma do perfil) e direita */
static const int GEO_JAN[3][2] = { {15, 21}, {COL_INI_PCT, COL_FIM_PCT}, {79, 85} };
static const char *const GEO_NOME[3] = { "esquerda", "centro", "direita" };

/* luma da coluna x na linha y fracionaria (interpolacao linear entre linhas vizinhas) */
static double luma_xy(const struct quadro *q, int x, double y) {
  if (y < 0) y = 0;
  if (y > q->alt - 1) y = q->alt - 1;
  int y0 = (int)y, y1 = y0 + 1 < q->alt ? y0 + 1 : y0;
  double f = y - y0;
  return q->dados[(size_t)y0 * q->stride + 2 * x] * (1 - f)
       + q->dados[(size_t)y1 * q->stride + 2 * x] * f;
}

/* perfil de linhas das colunas [c0,c1). Cada coluna e lida deslocada de inc*(x - centro):
 * com inc = inclinacao local (px por px) as faixas ficam retas na janela e a borda medida
 * nao soma o escorrimento da inclinacao. inc = 0 e o perfil simples. */
static void perfil_janela(const struct quadro *q, int c0, int c1, double inc, double *p) {
  double xc = (c0 + c1 - 1) / 2.0;
  for (int y = 0; y < q->alt; y++) {
    double s = 0;
    for (int x = c0; x < c1; x++) s += luma_xy(q, x, y + inc * (x - xc));
    p[y] = s / (c1 - c0);
  }
}

/* faixas claras do perfil no trecho [ya,yb): limiar no meio entre o minimo e o maximo do
 * trecho. Devolve quantas achou (grava ate MAXFAIXAS ini/fim, fim exclusivo) e o centro de
 * cada uma: media das linhas ponderada pelo quanto a luma passa do limiar. */
static int achar_faixas(const double *p, int ya, int yb, int *ini, int *fim, double *cen) {
  double mn = 1e9, mx = -1e9;
  for (int y = ya; y < yb; y++) { if (p[y] < mn) mn = p[y]; if (p[y] > mx) mx = p[y]; }
  double lim = (mn + mx) / 2;
  int achou = 0, dentro = 0;
  double sp = 0, spy = 0;
  for (int y = ya; y <= yb; y++) {
    int acima = y < yb && p[y] > lim;
    if (acima) {
      if (!dentro) { dentro = 1; sp = spy = 0; if (achou < MAXFAIXAS) ini[achou] = y; }
      sp += p[y] - lim; spy += (p[y] - lim) * y;
    } else if (dentro) {
      dentro = 0;
      if (achou < MAXFAIXAS) { fim[achou] = y; cen[achou] = spy / sp; }
      achou++;
    }
  }
  return achou;
}

/* media do miolo (metade central) da faixa [a,b) */
static double miolo(const double *p, int a, int b) {
  int borda = (b - a) / 4, y0 = a + borda, y1 = b - borda;
  if (y1 <= y0) { y0 = a; y1 = b; }
  double s = 0;
  for (int y = y0; y < y1; y++) s += p[y];
  return s / (y1 - y0);
}

/* largura 10-90% das duas bordas do vao entre a faixa k e a k+1 (perfil endireitado).
 * Anda a partir do fundo do vao para cada lado ate cruzar 10% e 90% da subida (fracao
 * de linha por interpolacao). Soma as larguras em *soma e o numero de bordas em *nb;
 * devolve o fundo do vao. */
static double bordas_vao(const double *p, const int *ini, const int *fim, int k,
                         double *soma, int *nb) {
  int g = fim[k] - 1;
  for (int y = fim[k] - 1; y <= ini[k + 1]; y++) if (p[y] < p[g]) g = y;
  double lo = p[g];
  for (int lado = 0; lado < 2; lado++) {
    /* lado 0: descida da faixa k (anda para cima); lado 1: subida da faixa k+1 (para baixo) */
    int f = k + lado, passo = lado ? 1 : -1, lim = lado ? fim[f] - 1 : ini[f];
    double hi = miolo(p, ini[f], fim[f]);
    if (hi - lo < 1) continue;          /* sem subida que se meca */
    double l10 = lo + 0.1 * (hi - lo), l90 = lo + 0.9 * (hi - lo), t10 = -1, t90 = -1;
    for (int y = g + passo; lado ? y <= lim : y >= lim; y += passo) {
      int ant = y - passo;     /* vizinho do lado do vao, abaixo do nivel */
      if (t10 < 0 && p[y] >= l10) t10 = y - passo * (p[y] - l10) / (p[y] - p[ant]);
      if (p[y] >= l90) { t90 = y - passo * (p[y] - l90) / (p[y] - p[ant]); break; }
    }
    if (t10 >= 0 && t90 >= 0) { *soma += (t90 - t10) * passo; (*nb)++; }
  }
  return lo;
}

static double zero_limpo(double v, double res) { return fabs(v) < res / 2 ? 0 : v; }

static int geometria_cmd(const char *dev, const char *arq, int skip) {
  int fini[MAXFAIXAS], ffim[MAXFAIXAS], n = 0;
  FILE *f = fopen(arq, "r");
  if (!f) { fprintf(stderr, "open %s: %s\n", arq, strerror(errno)); return 1; }
  while (n < MAXFAIXAS && fscanf(f, "%d %d", &fini[n], &ffim[n]) == 2) n++;
  fclose(f);
  if (n < 3) { fprintf(stderr, "%s: faixas insuficientes (%d)\n", arq, n); return 1; }

  struct quadro q = {0};
  if (obter_quadro(dev, skip, &q)) return 1;
  for (int i = 0; i < n; i++)
    if (fini[i] < 0 || ffim[i] > q.alt || ffim[i] <= fini[i] || (i && fini[i] < ffim[i - 1])) {
      fprintf(stderr, "faixa %d fora do quadro ou fora de ordem (%d..%d, altura %d)\n",
              i, fini[i], ffim[i], q.alt);
      free(q.dados); return 1;
    }
  double *p = malloc(sizeof(double) * q.alt);
  if (!p) { free(q.dados); return 1; }

  /* trecho de busca: a pilha do faixas.txt com folga de 1/8 da altura para cada lado (a
   * inclinacao e o trapezio deslocam a pilha nas colunas de fora) */
  int ya = fini[0] - q.alt / 8, yb = ffim[n - 1] + q.alt / 8;
  if (ya < 0) ya = 0;
  if (yb > q.alt) yb = q.alt;

  int ini[3][MAXFAIXAS], fim[3][MAXFAIXAS], c0[3], c1[3], rc = 0;
  double cen[3][MAXFAIXAS], xc[3];
  for (int j = 0; j < 3; j++) {
    c0[j] = q.larg * GEO_JAN[j][0] / 100; c1[j] = q.larg * GEO_JAN[j][1] / 100;
    xc[j] = (c0[j] + c1[j] - 1) / 2.0;
    perfil_janela(&q, c0[j], c1[j], 0, p);
    int k = achar_faixas(p, ya, yb, ini[j], fim[j], cen[j]);
    if (k != n) {
      fprintf(stderr, "coluna %s (%d a %d%%): %d faixas, esperadas %d\n",
              GEO_NOME[j], GEO_JAN[j][0], GEO_JAN[j][1], k, n);
      rc = 3;
    }
  }
  if (rc) { free(p); free(q.dados); return rc; }

  /* inclinacao: reta (minimos quadrados) do centro de cada faixa nas tres colunas; media das
   * faixas. Positiva = as faixas descem para a direita no quadro (y do quadro cresce para baixo).
   * Inclinacao local de cada janela (para endireitar o perfil): esquerda-centro, a media, centro-direita. */
  double xm = (xc[0] + xc[1] + xc[2]) / 3, sxx = 0, incl = 0, inc_loc[3] = {0, 0, 0};
  for (int j = 0; j < 3; j++) sxx += (xc[j] - xm) * (xc[j] - xm);
  for (int i = 0; i < n; i++) {
    double ym = (cen[0][i] + cen[1][i] + cen[2][i]) / 3, sxy = 0;
    for (int j = 0; j < 3; j++) sxy += (xc[j] - xm) * (cen[j][i] - ym);
    incl += sxy / sxx;
    inc_loc[0] += (cen[1][i] - cen[0][i]) / (xc[1] - xc[0]);
    inc_loc[2] += (cen[2][i] - cen[1][i]) / (xc[2] - xc[1]);
  }
  incl /= n; inc_loc[0] /= n; inc_loc[2] /= n; inc_loc[1] = incl;
  double alt_esq = cen[0][n - 1] - cen[0][0], alt_dir = cen[2][n - 1] - cen[2][0];

  /* bordas e contraste no perfil endireitado de cada janela */
  double borda[3], claro = 0, vao = 0;
  for (int j = 0; j < 3 && !rc; j++) {
    perfil_janela(&q, c0[j], c1[j], inc_loc[j], p);
    if (achar_faixas(p, ya, yb, ini[j], fim[j], cen[j]) != n) {
      fprintf(stderr, "coluna %s: as faixas nao se separam no perfil endireitado\n", GEO_NOME[j]);
      rc = 3; break;
    }
    double soma = 0; int nb = 0;
    for (int k = 0; k + 1 < n; k++) {
      double lo = bordas_vao(p, ini[j], fim[j], k, &soma, &nb);
      if (j == 1) vao += lo;
    }
    if (j == 1) for (int k = 0; k < n; k++) claro += miolo(p, ini[j][k], fim[j][k]);
    if (nb == 0) { fprintf(stderr, "coluna %s: nenhuma borda medida\n", GEO_NOME[j]); rc = 1; break; }
    borda[j] = soma / nb;
  }
  free(p); free(q.dados);
  if (rc) return rc;
  claro /= n; vao /= n - 1;
  if (alt_esq <= 0 || claro <= 0) { fprintf(stderr, "pilha de faixas degenerada\n"); return 1; }

  printf("inclinacao_graus=%.2f\n", zero_limpo(atan(incl) * 180 / M_PI, 0.01));
  printf("trapezio_pct=%.1f\n", zero_limpo((alt_dir / alt_esq - 1) * 100, 0.1));
  printf("borda_centro_px=%.2f\n", borda[1]);
  printf("borda_esq_px=%.2f\n", borda[0]);
  printf("borda_dir_px=%.2f\n", borda[2]);
  printf("contraste_centro=%.2f\n", (claro - vao) / claro);
  printf("quadro=%dx%d\n", q.larg, q.alt);
  return 0;
}

/* ---- bloco 11 (19A): mapa de nitidez 3x3 (so le o quadro) ------------------------ */

/* As colunas nao sao janelas fixas do quadro: saem da largura da imagem projetada ACHADA no
 * quadro (a imagem nao ocupa o quadro inteiro e muda de lugar com a correcao de 4 pontos). */
#define NIT_LADO_PCT 10   /* centro das colunas de fora: 10% e 90% da largura da imagem achada */
#define NIT_JAN_PCT 6     /* largura de cada coluna: 6% da largura da imagem achada */
#define NIT_SUAVE 4       /* media movel (+-colunas) do desvio por coluna */
#define NIT_LARG_MIN 20   /* imagem achada mais estreita que 20% do quadro: nao e a calibracao */

/* Largura da imagem projetada: em cada coluna, o desvio padrao da luma nas linhas [ya,yb)
 * (dentro da imagem as faixas alternam claro e escuro; fora, parede lisa, acesa ou nao).
 * Limiar na metade do maior desvio; a imagem e o trecho acima dele que contem o meio do
 * quadro. Devolve 0 e [*xe, *xd) (fim exclusivo). */
static int extensao_imagem(const struct quadro *q, int ya, int yb, int *xe, int *xd) {
  double *dp = malloc(sizeof(double) * q->larg), *sv = malloc(sizeof(double) * q->larg);
  if (!dp || !sv) { free(dp); free(sv); return 1; }
  for (int x = 0; x < q->larg; x++) {
    double s = 0, s2 = 0;
    for (int y = ya; y < yb; y++) {
      double v = q->dados[(size_t)y * q->stride + 2 * x];
      s += v; s2 += v * v;
    }
    double m = s / (yb - ya), var = s2 / (yb - ya) - m * m;
    dp[x] = var > 0 ? sqrt(var) : 0;
  }
  double mx = 0;
  for (int x = 0; x < q->larg; x++) {
    int a = x - NIT_SUAVE < 0 ? 0 : x - NIT_SUAVE, b = x + NIT_SUAVE >= q->larg ? q->larg - 1 : x + NIT_SUAVE;
    double s = 0;
    for (int i = a; i <= b; i++) s += dp[i];
    sv[x] = s / (b - a + 1);
    if (sv[x] > mx) mx = sv[x];
  }
  double lim = mx / 2;
  int meio = q->larg / 2, e = meio, d = meio;
  if (mx <= 0 || sv[meio] <= lim) { free(dp); free(sv); return 1; }
  while (e > 0 && sv[e - 1] > lim) e--;
  while (d + 1 < q->larg && sv[d + 1] > lim) d++;
  free(dp); free(sv);
  *xe = e; *xd = d + 1;
  return (*xd - *xe) * 100 < NIT_LARG_MIN * q->larg;
}

static int nitidez_cmd(const char *dev, const char *arq, int skip) {
  int fini[MAXFAIXAS], ffim[MAXFAIXAS], n = 0;
  FILE *f = fopen(arq, "r");
  if (!f) { fprintf(stderr, "open %s: %s\n", arq, strerror(errno)); return 1; }
  while (n < MAXFAIXAS && fscanf(f, "%d %d", &fini[n], &ffim[n]) == 2) n++;
  fclose(f);
  /* 3 grupos de vaos (um por linha da grade): pelo menos 4 faixas */
  if (n < 4) { fprintf(stderr, "%s: faixas insuficientes (%d)\n", arq, n); return 1; }

  struct quadro q = {0};
  if (obter_quadro(dev, skip, &q)) return 1;
  for (int i = 0; i < n; i++)
    if (fini[i] < 0 || ffim[i] > q.alt || ffim[i] <= fini[i] || (i && fini[i] < ffim[i - 1])) {
      fprintf(stderr, "faixa %d fora do quadro ou fora de ordem (%d..%d, altura %d)\n",
              i, fini[i], ffim[i], q.alt);
      free(q.dados); return 1;
    }
  /* o mesmo trecho de busca da geometria: a pilha com folga de 1/8 da altura */
  int ya = fini[0] - q.alt / 8, yb = ffim[n - 1] + q.alt / 8;
  if (ya < 0) ya = 0;
  if (yb > q.alt) yb = q.alt;

  int xe, xd;
  if (extensao_imagem(&q, ya, yb, &xe, &xd)) {
    fprintf(stderr, "a imagem projetada nao aparece no quadro (sem faixas no meio)\n");
    free(q.dados); return 3;
  }
  double *p = malloc(sizeof(double) * q.alt);
  if (!p) { free(q.dados); return 1; }

  static const int POS[3] = { NIT_LADO_PCT, 50, 100 - NIT_LADO_PCT };
  int w = xd - xe, meia = w * NIT_JAN_PCT / 200, c0[3], c1[3], rc = 0;
  if (meia < 1) meia = 1;
  int ini[3][MAXFAIXAS], fim[3][MAXFAIXAS];
  double cen[3][MAXFAIXAS], xc[3];
  for (int j = 0; j < 3; j++) {
    int centro = xe + w * POS[j] / 100;
    c0[j] = centro - meia; c1[j] = centro + meia;
    if (c0[j] < 0) c0[j] = 0;
    if (c1[j] > q.larg) c1[j] = q.larg;
    xc[j] = (c0[j] + c1[j] - 1) / 2.0;
    perfil_janela(&q, c0[j], c1[j], 0, p);
    int k = achar_faixas(p, ya, yb, ini[j], fim[j], cen[j]);
    if (k != n) {
      fprintf(stderr, "coluna c%d (x %d a %d): %d faixas, esperadas %d\n", j + 1, c0[j], c1[j], k, n);
      rc = 3;
    }
  }
  if (rc) { free(p); free(q.dados); return rc; }

  /* inclinacao local de cada coluna (como na geometria): c1-c2, a reta das tres, c2-c3 */
  double xm = (xc[0] + xc[1] + xc[2]) / 3, sxx = 0, inc[3] = {0, 0, 0};
  for (int j = 0; j < 3; j++) sxx += (xc[j] - xm) * (xc[j] - xm);
  for (int i = 0; i < n; i++) {
    double ym = (cen[0][i] + cen[1][i] + cen[2][i]) / 3, sxy = 0;
    for (int j = 0; j < 3; j++) sxy += (xc[j] - xm) * (cen[j][i] - ym);
    inc[1] += sxy / sxx;
    inc[0] += (cen[1][i] - cen[0][i]) / (xc[1] - xc[0]);
    inc[2] += (cen[2][i] - cen[1][i]) / (xc[2] - xc[1]);
  }
  for (int j = 0; j < 3; j++) inc[j] /= n;

  /* bordas por regiao: os vaos da coluna em tres grupos, de cima para baixo no quadro */
  double nit[3][3];
  for (int j = 0; j < 3 && !rc; j++) {
    perfil_janela(&q, c0[j], c1[j], inc[j], p);
    if (achar_faixas(p, ya, yb, ini[j], fim[j], cen[j]) != n) {
      fprintf(stderr, "coluna c%d: as faixas nao se separam no perfil endireitado\n", j + 1);
      rc = 3; break;
    }
    double soma[3] = {0, 0, 0}; int nb[3] = {0, 0, 0};
    for (int k = 0; k + 1 < n; k++) {
      int g = k * 3 / (n - 1);
      bordas_vao(p, ini[j], fim[j], k, &soma[g], &nb[g]);
    }
    for (int g = 0; g < 3; g++) {
      if (nb[g] == 0) { fprintf(stderr, "regiao r%dc%d: nenhuma borda medida\n", g + 1, j + 1); rc = 3; break; }
      nit[g][j] = soma[g] / nb[g];
    }
  }
  free(p); free(q.dados);
  if (rc) return rc;
  for (int g = 0; g < 3; g++)
    for (int j = 0; j < 3; j++) printf("nitidez_r%dc%d=%.2f\n", g + 1, j + 1, nit[g][j]);
  printf("quadro=%dx%d\n", q.larg, q.alt);
  return 0;
}

int main(int argc, char **argv) {
  if (argc >= 2 && strcmp(argv[1], "info") == 0)
    return info(argc >= 3 ? argv[2] : "/dev/video0");
  if (argc >= 7 && strcmp(argv[1], "grab") == 0)
    return grab(argv[2], argv[3], atoi(argv[4]), atoi(argv[5]), argv[6],
                argc >= 8 ? atoi(argv[7]) : 10);
  if (argc >= 5 && strcmp(argv[1], "faixas") == 0)
    return faixas_cmd(argv[2], atoi(argv[3]), argv[4], argc >= 6 ? atoi(argv[5]) : 15);
  if (argc >= 4 && strcmp(argv[1], "niveis") == 0)
    return niveis_cmd(argv[2], argv[3], argc >= 5 ? atoi(argv[4]) : 15);
  if (argc >= 4 && strcmp(argv[1], "geometria") == 0)
    return geometria_cmd(argv[2], argv[3], argc >= 5 ? atoi(argv[4]) : 15);
  if (argc >= 4 && strcmp(argv[1], "nitidez") == 0)
    return nitidez_cmd(argv[2], argv[3], argc >= 5 ? atoi(argv[4]) : 15);
  fprintf(stderr, "uso: nl_camcheck info [dev] | grab dev MJPG|YUYV larg alt saida [descarte]\n"
                  "     | faixas dev N saida.txt [descarte] | niveis dev faixas.txt [descarte]\n"
                  "     | geometria dev faixas.txt [descarte] | nitidez dev faixas.txt [descarte]\n");
  return 2;
}
