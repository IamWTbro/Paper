#!/usr/bin/env bash

(
set -e
PS1="$"
basedir="$(cd "$1" && pwd -P)"
workdir="$basedir/work"
minecraftversion=$(cat "$workdir/BuildData/info.json"  | grep minecraftVersion | cut -d '"' -f 4)
windows="$([[ "$OSTYPE" == "cygwin" || "$OSTYPE" == "msys" ]] && echo "true" || echo "false")"
spigotdecompiledir="$workdir/Minecraft/$minecraftversion-spigot"
forgedecompiledir="$workdir/Minecraft/$minecraftversion"
forgeflowerversion="1.5.380.19"
forgeflowerurl="http://files.minecraftforge.net/maven/net/minecraftforge/forgeflower/$forgeflowerversion/forgeflower-$forgeflowerversion.jar"
forgeflowerbin="$workdir/ForgeFlower/$forgeflowerversion.jar"
forgefloweroptions="-dgs=1 -hdc=0 -asc=1 -udv=1 -jvn=1"
forgeflowercachefile="$forgedecompiledir/forgeflowercache"
forgeflowercachevalue="$forgeflowerversion - $forgefloweroptions";
classdir="$spigotdecompiledir/classes"

mkdir -p "$workdir/ForgeFlower"

echo "Extracting NMS classes..."
if [ ! -d "$classdir" ]; then
    mkdir -p "$classdir"
    cd "$classdir"
    set +e
    jar xf "$spigotdecompiledir/$minecraftversion-mapped.jar" net/minecraft/server
    if [ "$?" != "0" ]; then
        cd "$basedir"
        echo "Failed to extract NMS classes."
        exit 1
    fi
    set -e
fi

needsDecomp=0
if [ ! -f "$forgeflowercachefile" ]; then
    needsDecomp=1
elif [ "$(cat ${forgeflowercachefile})" != "$forgeflowercachevalue" ]; then
    needsDecomp=1
fi
if [ "$needsDecomp" == "1" ]; then
    # our local cache is now invalidated, we can update forgeflower to get better deobfuscation
    rm -rf "$forgedecompiledir/net/"
fi

if [ ! -d "$forgedecompiledir/net/minecraft/server" ] ; then
    echo "Decompiling classes (stage 1)..."
    cd "$basedir"

    if [ ! -f "$forgeflowerbin" ]; then
        echo "Downloading ForgeFlower ($forgeflowerversion)..."
        curl -s -o "$forgeflowerbin" "$forgeflowerurl"
    fi

    set +e
    # TODO: Make this better? We don't need spigot compat for this stage
    java -jar "$forgeflowerbin" ${forgefloweroptions} -ind='    ' "$classdir" "$forgedecompiledir"
    if [ "$?" != "0" ]; then
        rm -rf "$forgedecompiledir/net/"
        echo "Failed to decompile classes."
        exit 1
    fi
    echo "$forgeflowerversion" > "$forgeflowercachefile"
    set -e
fi

if [ ! -d "$spigotdecompiledir/net/minecraft/server" ]; then
    echo "Decompiling classes (stage 2)..."
    cd "$basedir"
    set +e
    java -jar "$workdir/BuildData/bin/fernflower.jar" -dgs=1 -hdc=0 -asc=1 -udv=0 "$classdir" "$spigotdecompiledir"
    if [ "$?" != "0" ]; then
        echo "Failed to decompile classes."
        exit 1
    fi
    set -e
fi


# set a symlink to current
currentlink="$workdir/Minecraft/current"
if ([ ! -e "$currentlink" ] || [ -L "$currentlink" ]) && [ "$windows" == "false" ]; then
	set +e
	echo "Pointing $currentlink to $minecraftversion"
	rm -rf "$currentlink" || true
	ln -sfn "$minecraftversion" "$currentlink" || echo "Failed to set current symlink"
fi

)
