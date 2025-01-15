# Maintainer:  <samueld@mailo.com>
pkgname=simple-youtube
pkgver=0.0.1
pkgrel=1
pkgdesc="Simple script to access youtube"
arch=(any)
url="https://www.github.com/BrachystochroneSD/simple-youtube"
license=('GPL')
depends=(mpv curl)
optdepends=()
backup=(etc/yt.conf)
source=(
  yt.sh
  yt.conf
)
sha256sums=(
            )

package() {
  install -Dm600 yt.conf "$pkgdir/etc/yt.conf"
  install -Dm755 yt.sh "$pkgdir/usr/bin/yt"
}
