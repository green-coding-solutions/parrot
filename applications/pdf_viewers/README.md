# Benchmarking PDF viewers

Data from https://popcon.debian.org for usage

```text
package                   inst     vote     old      recent
firefox-esr               122963   53553    29781    39623
evince                    83061    22080    48415    12553
okular                    37940    11972    20046    5918
atril                     34819    10515    19052    5246
chromium                  29016    8634     7877     12493
mupdf-tools               19538    1319     9702     8515
qpdfview                  7837     849      5866     1119
firefox                   6090     4251     533      1262
xpdf                      4698     663      3781     237
gv                        3619     282      3150     187
papers                    3425     1452     1379     594
zathura                   3041     709      2053     279
zathura-pdf-poppler       3026     708      2039     279
mupdf                     2118     387      946      785
sioyek                    227      34       179      13
epdfview                  106      12       94       0
foxitreader               0        0        0        0
llpp                      0        0        0        0
mupdf-gl                  0        0        0        0
xreader                   0        0        0        0
zathura-pdf-mupdf         0        0        0        0
```

processed with this scrip

```shell
#!/usr/bin/env bash

pkgs=(evince okular xpdf mupdf mupdf-tools mupdf-gl zathura zathura-pdf-poppler \
      zathura-pdf-mupdf qpdfview atril xreader epdfview sioyek papers llpp gv \
      firefox firefox-esr chromium foxitreader)

curl -sS https://popcon.debian.org/main/by_inst.gz     | zcat >  /tmp/by_inst
curl -sS https://popcon.debian.org/non-free/by_inst.gz | zcat >> /tmp/by_inst
curl -sS https://popcon.debian.org/contrib/by_inst.gz  | zcat >> /tmp/by_inst

printf '%-25s %-8s %-8s %-8s %-8s\n' package inst vote old recent
{
  for p in "${pkgs[@]}"; do
    awk -v p="$p" '$2==p {printf "%s\t%s\t%s\t%s\t%s\n",$2,$3,$4,$5,$6; found=1; exit}
                   END   {if(!found) printf "%s\t0\t0\t0\t0\n",p}' /tmp/by_inst
  done
} | sort -k2,2nr -k3,3nr \
  | awk '{printf "%-25s %-8s %-8s %-8s %-8s\n",$1,$2,$3,$4,$5}'
```
