#include <stddef.h>

void *memcpy(void *dst, const void *src, size_t n) {
  unsigned char *d = dst;
  const unsigned char *s = src;
  for (size_t i = 0; i < n; ++i) d[i] = s[i];
  return dst;
}

void *memmove(void *dst, const void *src, size_t n) {
  unsigned char *d = dst;
  const unsigned char *s = src;
  if (d < s) {
    for (size_t i = 0; i < n; ++i) d[i] = s[i];
  } else {
    for (size_t i = n; i > 0; --i) d[i - 1] = s[i - 1];
  }
  return dst;
}

void *memset(void *dst, int value, size_t n) {
  unsigned char *d = dst;
  for (size_t i = 0; i < n; ++i) d[i] = (unsigned char)value;
  return dst;
}

int memcmp(const void *a, const void *b, size_t n) {
  const unsigned char *x = a;
  const unsigned char *y = b;
  for (size_t i = 0; i < n; ++i) {
    if (x[i] != y[i]) return x[i] - y[i];
  }
  return 0;
}

size_t strlen(const char *s) {
  size_t n = 0;
  while (s[n] != 0) ++n;
  return n;
}
