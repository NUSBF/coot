#!/bin/bash

BUILD_START=$(date +%s)

# Set up installation directory structure
export INSTALL_BASE="$(pwd)/install/coot"
export DEPS_DIR="$INSTALL_BASE/dependencies"

# Create main directories
mkdir -p "$INSTALL_BASE" "$DEPS_DIR"

# Define dependency installation paths - CORRECTED VERSIONS
export BOOST_DIR="$DEPS_DIR/boost-1.87.0"
export RDKIT_DIR="$DEPS_DIR/rdkit-2024.09.4"
export GTK4_DIR="$DEPS_DIR/gtk4-4.12.5"
export MMDB2_DIR="$DEPS_DIR/mmdb2-2.0.22"  # This is correct
export SSM_DIR="$DEPS_DIR/ssm-1.4"
export CLIPPER_DIR="/usr"
export RDKIT_LIB_DIR="$RDKIT_DIR/lib"

# --- ADDED: RPATH PATHS ---
ROOT_DIR="$(pwd)"
GLIB_LIB="$ROOT_DIR/glib-2.82.2/install/lib"
CAIRO_LIB="$ROOT_DIR/cairo-1.18.0/install/lib/x86_64-linux-gnu"
HB_LIB="$ROOT_DIR/harfbuzz-8.4.0/install/lib"
PANGO_LIB="$ROOT_DIR/pango-1.52.0/install/lib/x86_64-linux-gnu"
GTK_LIB="$ROOT_DIR/gtk-4.12.5/install/lib/x86_64-linux-gnu"

# Create directories for each dependency
mkdir -p "$BOOST_DIR" "$BOOST_DIR/lib" "$BOOST_DIR/include"
mkdir -p "$RDKIT_DIR" "$RDKIT_DIR/lib"
mkdir -p "$GTK4_DIR" "$GTK4_DIR/lib" "$GTK4_DIR/include" "$GTK4_DIR/share/glib-2.0/schemas"
mkdir -p "$MMDB2_DIR" "$MMDB2_DIR/lib" "$MMDB2_DIR/include"
mkdir -p "$SSM_DIR" "$SSM_DIR/lib" "$SSM_DIR/include"
mkdir -p "$INSTALL_BASE/bin" "$INSTALL_BASE/lib" "$INSTALL_BASE/include"

# Set environment variables
export Boost_NO_SYSTEM_PATHS=ON
export BOOST_ROOT="$BOOST_DIR"
export BOOST_LIBRARYDIR="$BOOST_DIR/lib"
export LD_LIBRARY_PATH="$ROOT_DIR/pango-1.52.0/install/lib/x86_64-linux-gnu:$ROOT_DIR/cairo-1.18.0/install/lib/x86_64-linux-gnu:$ROOT_DIR/harfbuzz-8.4.0/install/lib:$ROOT_DIR/glib-2.82.2/install/lib:$DEPS_DIR/gemmi/lib:$CLIPPER_DIR/lib:$SSM_DIR/lib:$MMDB2_DIR/lib:$GTK4_DIR/lib/x86_64-linux-gnu:$RDKIT_DIR/lib:$INSTALL_BASE/lib:$LD_LIBRARY_PATH"
export PKG_CONFIG_PATH="$CLIPPER_DIR/lib/pkgconfig:$SSM_DIR/lib/pkgconfig:$GTK4_DIR/lib/x86_64-linux-gnu/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:$INSTALL_BASE/lib/pkgconfig:$MMDB2_DIR/lib/pkgconfig:$PKG_CONFIG_PATH"
export CPPFLAGS="-I$INSTALL_BASE/include -I$GTK4_DIR/include -I$MMDB2_DIR/include -I$SSM_DIR/include -I$CLIPPER_DIR/include"
export CXXFLAGS="$CPPFLAGS -fPIC"
export PATH="$GTK4_DIR/bin:$PATH"

# Coot extras place for dependencies
extras_place=http://www2.mrc-lmb.cam.ac.uk/personal/pemsley/coot/dependencies

# Function to handle errors
handle_error() {
    echo "Error: $1"
    if [ -f "config.log" ]; then
        echo "=== config.log contents ==="
        cat config.log
    fi
    exit 1
}

# Detect Python version for the dev package name (works on Debian 12/3.11 and Debian 13/3.13)
PYTHON_VER_PKG=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
PYTHON_DEV_PKG="libpython${PYTHON_VER_PKG}-dev"

# Check for required packages
required_packages="build-essential cmake git python3-dev swig libssl-dev libsqlite3-dev libcairo2-dev libpng-dev python3-pip libxcursor-dev libxdamage-dev libxfixes-dev libxcomposite-dev libxinerama-dev libxkbcommon-dev libxkbcommon-x11-dev\
 libgl-dev libegl-dev libgsl-dev libglm-dev python3-gi python3-gi-cairo meson libxrandr-dev gir1.2-gtk-4.0 libeigen3-dev python-gi-dev sfftw-dev sfftw2 libxi-dev libclipper-dev libccp4-dev\
 ${PYTHON_DEV_PKG}"

missing_packages=""
for pkg in $required_packages; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        missing_packages="$missing_packages $pkg"
    fi
done

# Check if the symlink for libccp4c.pc exists, create it if it doesn't
if [ -f "/usr/lib/x86_64-linux-gnu/pkgconfig/ccp4c.pc" ] && [ ! -f "/usr/lib/x86_64-linux-gnu/pkgconfig/libccp4c.pc" ]; then
    echo "Creating symbolic link for libccp4c.pc..."
    sudo ln -s /usr/lib/x86_64-linux-gnu/pkgconfig/ccp4c.pc /usr/lib/x86_64-linux-gnu/pkgconfig/libccp4c.pc
fi

# Add this after the required packages check
export PATH="$HOME/.local/bin:$PATH"
MESON_VER=$(meson --version 2>/dev/null)
if [ -z "$MESON_VER" ] || [ "$(printf '%s\n' '1.2.0' "$MESON_VER" | sort -V | head -1)" != '1.2.0' ]; then
    echo "Installing Meson..."
    pip3 install --user --upgrade "meson>=1.2.0" --break-system-packages
else
    echo "Meson already installed ($MESON_VER), skipping..."
fi

if [ ! -z "$missing_packages" ]; then
    echo "Missing required packages. Please install with:"
    echo "sudo apt-get install $missing_packages"
    exit 1
fi

# Download and build Boost
if [ -d "$BOOST_DIR/lib" ] && find "$BOOST_DIR/lib" -name "libboost_python*.so" | grep -q .; then
    echo "Boost already built, skipping..."
else
    echo "Building Boost..."
    if [ ! -d "boost_1_87_0" ]; then
        if [ ! -f "boost_1_87_0.tar.gz" ]; then
            wget https://archives.boost.io/release/1.87.0/source/boost_1_87_0.tar.gz || handle_error "Failed to download Boost"
        fi
        tar xf boost_1_87_0.tar.gz || handle_error "Failed to extract Boost"
    fi

    cd boost_1_87_0
    PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    echo "using python : $PYTHON_VERSION : /usr/bin/python3 : /usr/include/python$PYTHON_VERSION : $BOOST_DIR/lib ;" > user-config.jam
    ./bootstrap.sh --with-python=/usr/bin/python3
    ./b2 -j$(nproc) --with-python python=$PYTHON_VERSION --with-thread --with-system --with-serialization --with-iostreams --with-program_options install --prefix="$BOOST_DIR" --libdir="$BOOST_DIR/lib"
    cd ..
fi

# Build RDKit
if [ -d "rdkit/build" ] && [ -f "rdkit/build/CMakeCache.txt" ] && find "$RDKIT_DIR/lib" -maxdepth 1 -name "*.so" | grep -q .; then
    echo "RDKit already built, skipping..."
else
    echo "Building RDKit..."
    if [ ! -d "rdkit" ]; then
        git clone -b Release_2024_09_4 https://github.com/rdkit/rdkit.git
    fi
    cd rdkit
    mkdir -p build
    cd build

    cmake .. \
        -DCMAKE_INSTALL_PREFIX="$RDKIT_DIR" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_PREFIX_PATH="$BOOST_DIR" \
        -DBoost_NO_SYSTEM_PATHS=ON \
        -DBoost_ROOT="$BOOST_DIR" \
        -DBOOST_LIBRARYDIR="$BOOST_DIR/lib" \
        -DBoost_USE_STATIC_LIBS=OFF \
        -DBoost_USE_STATIC_RUNTIME=OFF \
        -DRDK_BUILD_CAIRO_SUPPORT=ON \
        -DRDK_INSTALL_STATIC_LIBS=OFF \
        || handle_error "RDKit cmake failed"

    make -j$(nproc) || handle_error "Build RDKit failed"
    make install || handle_error "Install RDKit failed"

    # Make sure all libraries are copied
    mkdir -p "$RDKIT_DIR/lib"
    echo "Copying RDKit libraries from build directory to $RDKIT_DIR/lib"
    cp -v lib/*.so* "$RDKIT_DIR/lib/"
    
    # Update LD_LIBRARY_PATH to include the RDKit build directory
    export LD_LIBRARY_PATH="$(pwd)/lib:$RDKIT_DIR/lib:$LD_LIBRARY_PATH"
    
    cd ..
    find Code -mindepth 1 -maxdepth 1 -exec ln -s {} . \;
    cd ..
fi

# Update CPPFLAGS to include RDKit paths
export CPPFLAGS="-I$(pwd) -I$(pwd)/rdkit -I$(pwd)/rdkit/Code $CPPFLAGS"

# Build MMDB2 FIRST (before SSM and Clipper which depend on it)
if [ -d "$MMDB2_DIR/lib" ] && [ -f "$MMDB2_DIR/lib/libmmdb2.so" ]; then
    echo "MMDB2 already built, skipping..."
else
    echo "Building MMDB2..."
    mkdir -p mmdb2-build
    cd mmdb2-build
    if [ ! -f "mmdb2-2.0.22.tar.gz" ]; then
        wget -O mmdb2-2.0.22.tar.gz $extras_place/mmdb2-2.0.22.tar.gz || handle_error "Failed to download MMDB2"
    fi
    tar xzf mmdb2-2.0.22.tar.gz || handle_error "Failed to extract MMDB2"
    
    # Find the extracted directory
    MMDB_EXTRACTED_DIR=$(find . -maxdepth 1 -type d -name "mmdb2-*" | head -1)
    if [ -z "$MMDB_EXTRACTED_DIR" ]; then
        handle_error "Could not find extracted MMDB2 directory"
    fi
    
    cd "$MMDB_EXTRACTED_DIR"
    CFLAGS="-fPIC" CXXFLAGS="-fPIC" ./configure --prefix="$MMDB2_DIR" --enable-shared --disable-static || handle_error "MMDB2 configure failed"
    make -j$(nproc) || handle_error "MMDB2 make failed"
    make install || handle_error "MMDB2 install failed"
    cd ../../
fi

# Build GEMMI
if [ -d "$DEPS_DIR/gemmi" ] && [ -f "$DEPS_DIR/gemmi/lib/libgemmi_cpp.so" ]; then
    echo "GEMMI already built, skipping..."
else
    echo "Building GEMMI..."
    if [ ! -d "gemmi" ]; then
        git clone https://github.com/project-gemmi/gemmi.git
    fi
    cd gemmi
    mkdir -p build
    cd build
    
    cmake .. \
        -DCMAKE_INSTALL_PREFIX="$DEPS_DIR/gemmi" \
        -DCMAKE_BUILD_TYPE=Release \
        -DUSE_PYTHON=OFF \
        || handle_error "GEMMI cmake failed"
    
    make -j$(nproc) || handle_error "GEMMI make failed"
    make install || handle_error "GEMMI install failed"
    cd ../../
fi
export CPPFLAGS="-I$DEPS_DIR/gemmi/include $CPPFLAGS"
export LDFLAGS="-L$DEPS_DIR/gemmi/lib $LDFLAGS"


# Build SSM (after MMDB2, before Clipper)
if [ -d "$SSM_DIR/lib" ] && [ -f "$SSM_DIR/lib/libssm.so" ]; then
    echo "SSM already built, skipping..."
else
    echo "Building SSM..."
    mkdir -p ssm-build
    cd ssm-build
    if [ ! -f "ssm-1.4.tar.gz" ]; then
        wget -O ssm-1.4.tar.gz $extras_place/ssm-1.4.tar.gz || handle_error "Failed to download SSM"
    fi
    tar xzf ssm-1.4.tar.gz || handle_error "Failed to extract SSM"
    
    # Find the extracted directory
    SSM_EXTRACTED_DIR=$(find . -maxdepth 1 -type d -name "ssm*" | head -1)
    if [ -z "$SSM_EXTRACTED_DIR" ]; then
        handle_error "Could not find extracted SSM directory"
    fi
    
    cd "$SSM_EXTRACTED_DIR"
    
    export CPPFLAGS="-I$MMDB2_DIR/include"
    export LDFLAGS="-L$MMDB2_DIR/lib"
    
    ./configure --prefix="$SSM_DIR" \
        --enable-shared \
        --disable-static \
        CPPFLAGS="-I$MMDB2_DIR/include" \
        LDFLAGS="-L$MMDB2_DIR/lib" \
        || handle_error "SSM configure failed"
    
    make -j$(nproc) || handle_error "SSM make failed"
    make install || handle_error "SSM install failed"
    cd ../../
fi


# Build glib
if [ -d "glib-2.82.2/install" ]; then
    echo "glib already built, skipping..."
else
    echo "Building glib..."
    if [ ! -d "glib-2.82.2" ]; then
        if [ ! -f "glib-2.82.2.tar.xz" ]; then
            wget https://download.gnome.org/sources/glib/2.82/glib-2.82.2.tar.xz || handle_error "Failed to download glib"
        fi
        tar xf glib-2.82.2.tar.xz || handle_error "Failed to extract glib"
    fi
    cd glib-2.82.2 || exit 1
    # FIX: Inject RPATH
    export LDFLAGS="-Wl,-rpath,$GLIB_LIB"
    meson setup builddir --prefix=$(pwd)/install --libdir=lib \
        -Dintrospection=disabled \
        -Dsysprof=disabled \
        -Dsystemtap=false || handle_error "Failed to configure glib"
    cd builddir || exit 1
    ninja || handle_error "Failed to build glib"
    ninja install || handle_error "Failed to install glib"
    cd ../..
fi
#LD Library need to be updated once the glib library has been built
export LD_LIBRARY_PATH="$(pwd)/glib-2.82.2/install/lib:$LD_LIBRARY_PATH"

# Build cairo
if [ -d "cairo-1.18.0/install" ]; then
    echo "cairo already built, skipping..."
else
    echo "Building cairo..."
    if [ ! -d "cairo-1.18.0" ]; then
        if [ ! -f "cairo-1.18.0.tar.xz" ]; then
            wget https://cairographics.org/releases/cairo-1.18.0.tar.xz || handle_error "Failed to download cairo"
        fi
        tar xf cairo-1.18.0.tar.xz || handle_error "Failed to extract cairo"
    fi
    cd cairo-1.18.0 || exit 1
    # FIX: Inject RPATH and local glib pkgconfig
    export PKG_CONFIG_PATH="$GLIB_LIB/pkgconfig:$PKG_CONFIG_PATH"
    export LDFLAGS="-Wl,-rpath,$CAIRO_LIB:$GLIB_LIB"
    meson setup builddir --prefix=$(pwd)/install --pkg-config-path="$(pwd)/../glib-2.82.2/install/lib/pkgconfig" || handle_error "Failed to configure cairo"
    cd builddir || exit 1
    ninja || handle_error "Failed to build cairo"
    ninja install || handle_error "Failed to install cairo"
    cd ../..
fi

# Build harfbuzz
if [ -d "harfbuzz-8.4.0/install" ]; then
    echo "harfbuzz already built, skipping..."
else
    echo "Building harfbuzz..."
    if [ ! -d "harfbuzz-8.4.0" ]; then
        if [ ! -f "harfbuzz-8.4.0.tar.xz" ]; then
            wget https://github.com/harfbuzz/harfbuzz/releases/download/8.4.0/harfbuzz-8.4.0.tar.xz || handle_error "Failed to download harfbuzz"
        fi
        tar xf harfbuzz-8.4.0.tar.xz || handle_error "Failed to extract harfbuzz"
    fi
    cd harfbuzz-8.4.0 || exit 1
    # FIX: Inject RPATH and local deps
    export PKG_CONFIG_PATH="$GLIB_LIB/pkgconfig:$CAIRO_LIB/pkgconfig:$PKG_CONFIG_PATH"
    export LDFLAGS="-Wl,-rpath,$HB_LIB:$CAIRO_LIB:$GLIB_LIB"
    meson setup builddir --prefix=$(pwd)/install --libdir=lib \
        --pkg-config-path="$(pwd)/../glib-2.82.2/install/lib/pkgconfig:$(pwd)/../cairo-1.18.0/install/lib/pkgconfig" \
        -Dintrospection=disabled \
        -Dcpp_std=c++17 || handle_error "Failed to configure harfbuzz"
    cd builddir || exit 1
    ninja || handle_error "Failed to build harfbuzz"
    ninja install || handle_error "Failed to install harfbuzz"
    cd ../..
fi

# Build pango
if [ -d "pango-1.52.0/install" ]; then
    echo "pango already built, skipping..."
else
    echo "Building pango..."
    if [ ! -d "pango-1.52.0" ]; then
        if [ ! -f "pango-1.52.0.tar.xz" ]; then
            wget https://download.gnome.org/sources/pango/1.52/pango-1.52.0.tar.xz || handle_error "Failed to download pango"
        fi
        tar xf pango-1.52.0.tar.xz || handle_error "Failed to extract pango"
    fi
    cd pango-1.52.0 || exit 1
    # FIX: Inject RPATH and local deps
    export PKG_CONFIG_PATH="$GLIB_LIB/pkgconfig:$CAIRO_LIB/pkgconfig:$HB_LIB/pkgconfig:$PKG_CONFIG_PATH"
    export LDFLAGS="-Wl,-rpath,$PANGO_LIB:$HB_LIB:$CAIRO_LIB:$GLIB_LIB"
    meson setup builddir --prefix=$(pwd)/install \
--pkg-config-path="$(pwd)/../glib-2.82.2/install/lib/pkgconfig:$(pwd)/../cairo-1.18.0/install/lib/pkgconfig:$(pwd)/../harfbuzz-8.4.0/install/lib/pkgconfig" \
        -Dcairo=enabled \
        -Dintrospection=disabled || handle_error "Failed to configure pango"
    cd builddir || exit 1
    ninja || handle_error "Failed to build pango"
    ninja install || handle_error "Failed to install pango"
    cd ../..
fi

# Build GTK4
export PATH="$(pwd)/glib-2.82.2/install/bin:$PATH"
if [ -d "gtk-4.12.5/install" ]; then
    echo "GTK4 already built, skipping..."
else
    echo "Building GTK4..."
    if [ ! -d "gtk-4.12.5" ]; then
        if [ ! -f "gtk-4.12.5.tar.xz" ]; then
            wget https://download.gnome.org/sources/gtk/4.12/gtk-4.12.5.tar.xz || handle_error "Failed to download gtk4"
        fi
        tar xf gtk-4.12.5.tar.xz || handle_error "Failed to extract gtk4"
    fi
    cd gtk-4.12.5 || exit 1
    # FIX: Inject RPATH and local deps
    export PKG_CONFIG_PATH="$PANGO_LIB/pkgconfig:$HB_LIB/pkgconfig:$CAIRO_LIB/pkgconfig:$GLIB_LIB/pkgconfig:$PKG_CONFIG_PATH"
    export LDFLAGS="-Wl,-rpath,$GTK_LIB:$PANGO_LIB:$HB_LIB:$CAIRO_LIB:$GLIB_LIB"
    meson setup builddir --prefix=$(pwd)/install \
        --pkg-config-path="$(pwd)/../glib-2.82.2/install/lib/pkgconfig:$(pwd)/../cairo-1.18.0/install/lib/pkgconfig:$(pwd)/../pango-1.52.0/install/lib/pkgconfig:$(pwd)/../harfbuzz-8.4.0/install/lib/pkgconfig" \
        -Dx11-backend=true \
        -Dwayland-backend=false \
        -Dbroadway-backend=false \
        -Dmedia-gstreamer=disabled \
        -Dmedia-ffmpeg=disabled \
        -Dprint-cups=disabled \
        -Dintrospection=disabled || handle_error "Failed to configure gtk4"

    cd builddir || exit 1
    ninja || handle_error "Failed to build gtk4"
    ninja install || handle_error "Failed to install gtk4"
    cd ../..
fi

# Compile GSettings schemas
echo "Compiling GSettings schemas..."
glib-compile-schemas "$(pwd)/gtk-4.12.5/install/share/glib-2.0/schemas"

# Hash file records the git state the .o files were actually built from.
# Only written after a successful make, so failed builds don't advance the pointer.
COOT_BUILD_HASH_FILE="$(pwd)/.coot-built-hash"
LAST_BUILT_HASH=$(cat "$COOT_BUILD_HASH_FILE" 2>/dev/null || echo "none")

# Clone or update Coot repository
if [ -d "coot" ]; then
    echo "Coot directory already exists, updating..."
    cd coot
    git remote set-url origin https://github.com/pemsley/coot.git
    git fetch origin || handle_error "Failed to fetch upstream pemsley/coot"
    git reset --hard origin/main || handle_error "Failed to reset to upstream main"
else
    git clone https://github.com/pemsley/coot.git -b main coot || handle_error "Failed to clone upstream"
    cd coot
fi

# Apply nusbf patches on top of upstream
git remote remove nusbf 2>/dev/null || true
git remote add nusbf https://github.com/nusbf/coot.git
git fetch nusbf || handle_error "Failed to fetch nusbf/coot"
git merge nusbf/nusbf-patches --no-edit || handle_error "Failed to merge nusbf-patches"

# Patch upstream Makefile.am files missing library dependencies.
python3 - <<'PYEOF'
def patch_block(path, marker, anchor, insertion, label):
    text = open(path).read()
    start = text.find(marker)
    if start == -1:
        return
    end = text.find("\n\n", start)
    block = text[start:end]
    if insertion.strip() in block:
        return  # already patched
    new_text = text[:start] + block.replace(anchor, anchor + " \\\n\t" + insertion) + text[end:]
    open(path, "w").write(new_text)
    print(f"Patched {path}: {label}")

# Fix 1: libcoot-map-utils.la missing from coot-identify-protein-bin LDADD
patch_block("ligand/Makefile.am",
    "coot_identify_protein_bin_LDADD",
    "$(top_builddir)/coot-utils/libcoot-coord-utils.la",
    "$(top_builddir)/coot-utils/libcoot-map-utils.la",
    "added libcoot-map-utils.la")

# Fix 2: libcoot-ligand.la missing from libcootsumo_la_LIBADD
# molecular_replacement_search lives in ligand/ but libcootsumo.so doesn't link it
patch_block("src/Makefile.am",
    "libcootsumo_la_LIBADD",
    "$(LIBSSM_LIBS)",
    "$(top_builddir)/ligand/libcoot-ligand.la",
    "added libcoot-ligand.la to LIBADD")

# Fix 3: libcoot-ligand.la missing from coot_1_LDADD
# Debian 12 libtool (2.4.7) does not propagate dependency_libs of libcootsumo.la
# into the coot-1 final link, so molecular_replacement_search goes unresolved.
patch_block("src/Makefile.am",
    "coot_1_LDADD",
    "libcootsumo.la",
    "$(top_builddir)/ligand/libcoot-ligand.la",
    "added libcoot-ligand.la to coot_1_LDADD")
PYEOF
NEW_COOT_HASH=$(git rev-parse HEAD)
cd ..

cd coot

# Building coot
echo "Building Coot..."
./autogen.sh || handle_error "autogen.sh failed"
cp configure configure.orig
export PKG_CONFIG_PATH="$(pwd)/../glib-2.82.2/install/lib/pkgconfig:$(pwd)/../pango-1.52.0/install/lib/x86_64-linux-gnu/pkgconfig:$(pwd)/../cairo-1.18.0/install/lib/x86_64-linux-gnu/pkgconfig:$(pwd)/../harfbuzz-8.4.0/install/lib/pkgconfig:$(pwd)/../gtk-4.12.5/install/lib/x86_64-linux-gnu/pkgconfig:$CLIPPER_DIR/lib/pkgconfig:$SSM_DIR/lib/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:$INSTALL_BASE/lib/pkgconfig:$MMDB2_DIR/lib/pkgconfig:$PKG_CONFIG_PATH"
export CPPFLAGS="-I$(pwd)/.. -I$(pwd)/../rdkit -I$(pwd)/../gtk-4.12.5/install/include/gtk-4.0 -I$MMDB2_DIR/include -I$SSM_DIR/include -I$CLIPPER_DIR/include"

# Detect the active Python version to keep headers and libs in sync
PYTHON_VER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
PYTHON_LIBDIR=$(python3 -c "import sysconfig; print(sysconfig.get_config_var('LIBPL'))")
PYTHON_LIBS_FLAG="-L${PYTHON_LIBDIR} -lpython${PYTHON_VER}"
echo "Using Python ${PYTHON_VER}, PYTHON_LIBS=${PYTHON_LIBS_FLAG}"

# Configure Coot with the corrected settings
# FIX: Force coot to use the local stack via LDFLAGS and RPATH
./configure --prefix="$(pwd)/../install/coot" \
    --enable-shared \
    --with-boost="$BOOST_DIR" \
    --with-boost-libdir="$BOOST_DIR/lib" \
    --with-glm=/usr \
    --with-rdkit-prefix="$(pwd)/../rdkit" \
    CXXFLAGS="-g -O2 -Wall -Wno-unused -std=c++17 -include cstring -include fstream -fPIC -fpermissive -fopenmp -I/usr/include/python${PYTHON_VER} -I$MMDB2_DIR/include -I$DEPS_DIR/gemmi/include -DUSE_GEMMI=1 -DGEMMI_SHARED -DBOOST_IOSTREAMS_DYN_LINK -DBOOST_SERIALIZATION_DYN_LINK -DBOOST_SYSTEM_DYN_LINK -DBOOST_THREAD_DYN_LINK -DBOOST_IOSTREAMS_NO_LIB -DBOOST_SERIALIZATION_NO_LIB -DBOOST_SYSTEM_NO_LIB -DBOOST_THREAD_NO_LIB -DRDK_BUILD_CAIRO_SUPPORT -DRDK_64BIT_BUILD -DRDK_HAS_EIGEN3 -DRDK_USE_BOOST_IOSTREAMS -DRDK_USE_BOOST_SERIALIZATION -DCLIPPER_HAS_TOP8000 -DHAVE_SSMLIB -DMAKE_ENHANCED_LIGAND_TOOLS=1" \
    LDFLAGS="-L$DEPS_DIR/gemmi/lib -L$BOOST_DIR/lib -L$SSM_DIR/lib -L$MMDB2_DIR/lib -L$CLIPPER_DIR/lib -L$GTK_LIB -L$CAIRO_LIB -L$PANGO_LIB -L$HB_LIB -L$GLIB_LIB -L$RDKIT_LIB_DIR -Wl,-rpath,$BOOST_DIR/lib -Wl,-rpath,$GTK_LIB -Wl,-rpath,$CAIRO_LIB -Wl,-rpath,$PANGO_LIB -Wl,-rpath,$HB_LIB -Wl,-rpath,$GLIB_LIB -Wl,-rpath,$SSM_DIR/lib -Wl,-rpath,$MMDB2_DIR/lib -Wl,-rpath,$CLIPPER_DIR/lib -Wl,-rpath,$RDKIT_LIB_DIR" \
    LIBS="-lgemmi_cpp -lssm -lmmdb2 -lclipper-ccp4 -lclipper-core -lclipper-contrib -lclipper-mmdb -lclipper-minimol" \
    RDKIT_LIBS="-L$RDKIT_LIB_DIR -Wl,-rpath,$RDKIT_LIB_DIR -lRDKitGraphMol -lRDKitSmilesParse -lRDKitFileParsers -lRDKitRDGeneral -lRDKitDataStructs -lRDKitMolDraw2D -lRDKitForceFieldHelpers -lRDKitDescriptors -lRDKitForceField -lRDKitSubstructMatch -lRDKitOptimizer -lRDKitDistGeomHelpers -lRDKitDistGeometry -lRDKitChemReactions -lRDKitAlignment -lRDKitEigenSolvers -lRDKitDepictor -lRDKitMolChemicalFeatures -lRDKitPartialCharges -lRDKitRDGeometryLib -lRDKitShapeHelpers -lRDKitFingerprints -lRDKitMolAlign -lRDKitMolTransforms -lRDKitChemTransforms -lRDKitGenericGroups -lRDKitRingDecomposerLib -lRDKitFilterCatalog -lRDKitCatalogs -lRDKitSubgraphs -lRDKitPartialCharges -lRDKitMolOps -lRDKitmaeparser -lRDKitcoordgen -lboost_serialization -lboost_iostreams" \
    PYTHON_LIBS="$PYTHON_LIBS_FLAG" || handle_error "Configure failed"

# Cap parallel jobs to avoid OOM on machines with less RAM (e.g. Debian 12)
TOTAL_MEM_MB=$(awk '/MemTotal/ { printf "%d", $2/1024 }' /proc/meminfo)
NPROC=$(nproc)
# Allow roughly 1 job per 1.5 GB RAM, but never more than nproc
MAX_JOBS=$(( TOTAL_MEM_MB / 1536 ))
[ "$MAX_JOBS" -lt 1 ] && MAX_JOBS=1
[ "$MAX_JOBS" -gt "$NPROC" ] && MAX_JOBS=$NPROC
echo "Building with $MAX_JOBS parallel jobs (${TOTAL_MEM_MB} MB RAM, ${NPROC} cores)"

# Selectively clean only modules whose source files changed since the last successful build.
# LAST_BUILT_HASH tracks the git state the .o files were actually compiled from, so
# comparing against it (not the previous git HEAD) correctly handles failed builds too.
if [ "$LAST_BUILT_HASH" != "$NEW_COOT_HASH" ] && [ "$LAST_BUILT_HASH" != "none" ]; then
    echo "Source changed since last successful build ($LAST_BUILT_HASH -> $NEW_COOT_HASH), cleaning affected modules..."
    CHANGED_DIRS=$(git diff --name-only "$LAST_BUILT_HASH" "$NEW_COOT_HASH" 2>/dev/null \
        | grep -E '\.(cpp|cxx|cc|c|h|hh|hpp)$' \
        | sed 's|/[^/]*$||' \
        | sort -u)
    for dir in $CHANGED_DIRS; do
        [ -d "$dir" ] || continue
        echo "  Cleaning $dir..."
        find "$dir" -maxdepth 1 \( -name "*.o" -o -name "*.lo" -o -name "*.la" \) -delete 2>/dev/null || true
        [ -d "$dir/.libs" ] && find "$dir/.libs" -maxdepth 1 \
            \( -name "*.o" -o -name "*.so" -o -name "*.so.*" -o -name "*.la" \) \
            -delete 2>/dev/null || true
    done
fi
MAKE_LOG="$(pwd)/../coot-make.log"
echo "Make output logged to: $MAKE_LOG"
make -j$MAX_JOBS 2>&1 | tee "$MAKE_LOG"
if [ "${PIPESTATUS[0]}" -ne 0 ]; then
    echo "=== Last 50 lines of make output ==="
    tail -50 "$MAKE_LOG"
    handle_error "Coot make failed (see $MAKE_LOG for details)"
fi
make install || handle_error "Coot install failed"
# Record the source hash that was successfully built, for incremental cleaning next run
echo "$NEW_COOT_HASH" > "$COOT_BUILD_HASH_FILE"
cd ..

# Create the wrapper script
echo "Creating wrapper script for Coot..."

_INSTALL_BASE_REAL="$(realpath "$INSTALL_BASE")" || handle_error "Could not resolve INSTALL_BASE path: $INSTALL_BASE"
_BUILD_BASE_REAL="$(realpath "$(pwd)")" || handle_error "Could not resolve build base path"

WRAPPER_BIN_DIR="$INSTALL_BASE/bin"
if [ ! -d "$WRAPPER_BIN_DIR" ]; then
    mkdir -p "$WRAPPER_BIN_DIR" || handle_error "Failed to create bin dir: $WRAPPER_BIN_DIR"
fi

WRAPPER_PATH="$INSTALL_BASE/bin/coot"

cat > "$WRAPPER_PATH" << WEOF
#!/bin/bash

BASE_DIR="${_INSTALL_BASE_REAL}"
BUILD_DIR="${_BUILD_BASE_REAL}"
DEPS_DIR="\$BASE_DIR/dependencies"

export COOT_PREFIX="\$BASE_DIR"
export SYMINFO="\$BASE_DIR/share/coot/data/syminfo.lib"
export LD_LIBRARY_PATH="\$BUILD_DIR/gtk-4.12.5/install/lib/x86_64-linux-gnu:\$BUILD_DIR/pango-1.52.0/install/lib/x86_64-linux-gnu:\$BUILD_DIR/harfbuzz-8.4.0/install/lib:\$BUILD_DIR/cairo-1.18.0/install/lib/x86_64-linux-gnu:\$BUILD_DIR/glib-2.82.2/install/lib:\$DEPS_DIR/gemmi/lib:\$DEPS_DIR/boost-1.87.0/lib:\$DEPS_DIR/rdkit-2024.09.4/lib:\$DEPS_DIR/ssm-1.4/lib:\$DEPS_DIR/mmdb2-2.0.22/lib:\$BASE_DIR/lib:\$LD_LIBRARY_PATH"
export GSETTINGS_SCHEMA_DIR="\$BUILD_DIR/gtk-4.12.5/install/share/glib-2.0/schemas"
export XDG_DATA_DIRS="\$BUILD_DIR/gtk-4.12.5/install/share:\$BUILD_DIR/glib-2.82.2/install/share:\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

exec "\$BASE_DIR/libexec/coot-1" "\$@"
WEOF

[ -f "$WRAPPER_PATH" ] || handle_error "Wrapper script was not created at: $WRAPPER_PATH"
chmod +x "$WRAPPER_PATH" || handle_error "Failed to chmod wrapper script: $WRAPPER_PATH"
[ -x "$WRAPPER_PATH" ] || handle_error "Wrapper script at $WRAPPER_PATH is not executable"

COOT_BIN="$_INSTALL_BASE_REAL/libexec/coot-1"
[ -f "$COOT_BIN" ] || handle_error "coot-1 binary missing at: $COOT_BIN — installation is incomplete"

BUILD_END=$(date +%s)
BUILD_SECS=$(( BUILD_END - BUILD_START ))
BUILD_H=$(( BUILD_SECS / 3600 ))
BUILD_M=$(( (BUILD_SECS % 3600) / 60 ))
BUILD_S=$(( BUILD_SECS % 60 ))

echo "Installation complete!"
echo "Coot installed to: $INSTALL_BASE"
echo "Wrapper script:    $WRAPPER_PATH"
echo "To start Coot:     $WRAPPER_PATH"
printf "Build time:        %02dh %02dm %02ds\n" $BUILD_H $BUILD_M $BUILD_S
