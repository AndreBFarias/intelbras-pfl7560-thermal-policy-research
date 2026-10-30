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
 * Compilar (NDK r27c):
 *   armv7a-linux-androideabi24-clang -O2 -Wall -o nl_camcheck nl_camcheck.c
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

int main(int argc, char **argv) {
  if (argc >= 2 && strcmp(argv[1], "info") == 0)
    return info(argc >= 3 ? argv[2] : "/dev/video0");
  if (argc >= 7 && strcmp(argv[1], "grab") == 0)
    return grab(argv[2], argv[3], atoi(argv[4]), atoi(argv[5]), argv[6],
                argc >= 8 ? atoi(argv[7]) : 10);
  fprintf(stderr, "uso: nl_camcheck info [dev] | grab dev MJPG|YUYV larg alt saida [descarte]\n");
  return 2;
}
