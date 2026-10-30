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
 *       captura UM quadro YUYV (640x480; se nao houver, o menor tamanho
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

  void *mem[NBUF]; size_t len[NBUF];
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
      fwrite(mem[b.index], 1, b.bytesused, o);
      fclose(o);
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
#define COL_INI_PCT 35   /* perfil de linhas nas colunas 35 a 65% da largura */
#define COL_FIM_PCT 65
#define MARGEM 0.03      /* queda/subida que conta como inversao: 3% da amplitude */

struct quadro { unsigned char *dados; int larg, alt, stride; };

/* Captura UM quadro YUYV do V4L2 (descarta 'skip'). Tamanho: 640x480 se o
 * driver o oferece, senao o menor YUYV listado. Devolve 0 e preenche q. */
static int captura_yuyv(const char *dev, int skip, struct quadro *q) {
  int fd = open(dev, O_RDWR);
  if (fd < 0) { fprintf(stderr, "open %s: %s\n", dev, strerror(errno)); return 1; }

  unsigned w = 0, h = 0;
  struct v4l2_frmsizeenum fs;
  memset(&fs, 0, sizeof fs);
  fs.pixel_format = V4L2_PIX_FMT_YUYV;
  for (fs.index = 0; xioctl(fd, VIDIOC_ENUM_FRAMESIZES, &fs) == 0; fs.index++) {
    if (fs.type != V4L2_FRMSIZE_TYPE_DISCRETE) continue;
    unsigned fw = fs.discrete.width, fh = fs.discrete.height;
    if (fw == 640 && fh == 480) { w = fw; h = fh; break; }
    if (w == 0 || fw * fh < w * h) { w = fw; h = fh; }
  }
  if (w == 0) { w = 640; h = 480; }

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

  struct v4l2_requestbuffers rb;
  memset(&rb, 0, sizeof rb);
  rb.count = NBUF; rb.type = V4L2_BUF_TYPE_VIDEO_CAPTURE; rb.memory = V4L2_MEMORY_MMAP;
  if (xioctl(fd, VIDIOC_REQBUFS, &rb) < 0) { perror("REQBUFS"); close(fd); return 1; }

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
      if (b.bytesused < esperado) {
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
  if (larg <= 0 || alt <= 0) { fprintf(stderr, "L/A invalidos em %s\n", spec); free(c); return 1; }
  FILE *f = fopen(c, "rb");
  if (!f) { fprintf(stderr, "open %s: %s\n", c, strerror(errno)); free(c); return 1; }
  size_t n = (size_t)larg * 2 * alt;
  q->dados = malloc(n);
  if (!q->dados || fread(q->dados, 1, n, f) != n) {
    fprintf(stderr, "%s: menos de %zu bytes\n", c, n);
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
  fprintf(stderr, "uso: nl_camcheck info [dev] | grab dev MJPG|YUYV larg alt saida [descarte]\n"
                  "     | faixas dev N saida.txt [descarte] | niveis dev faixas.txt [descarte]\n");
  return 2;
}
