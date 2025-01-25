# Maintainer:  <samueld@mailo.com>
pkgname=simple-youtube
pkgver=0.0.4
pkgrel=1
pkgdesc="Simple script to access youtube"
arch=(any)
url="https://www.github.com/BrachystochroneSD/simple-youtube"
license=('GPL')
depends=(mpv curl)
optdepends=()
backup=(etc/yt.conf)
source=(
  yt.conf
  yt.sh
)
sha256sums=('4d309231e350460c6c5bae2603ca95bf1b73d8aedf6e6766fb5a96e0737c538d'
            'bcda3d5795f6b5a3784ee76bab017e90243da9dfa630f7bf8ecfeb8440fc2e79')

package() {
  install -Dm644 yt.conf "$pkgdir/etc/yt.conf"
  install -Dm755 yt.sh "$pkgdir/usr/bin/yt"
}
