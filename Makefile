SRC=$(wildcard libs/*.lua) $(wildcard src/*.lua)

mpv_crop_script.lua: $(SRC)
	./concat_files.py -r concat.json

mpv_crop_script.conf: mpv_crop_script.lua
	mpv av://lavfi:anullsrc --end 0 --quiet --no-config --script mpv_crop_script.lua --script-opts mpv_crop_script-example-config=mpv_crop_script.conf

clean:
	rm mpv_crop_script.lua mpv_crop_script.conf

