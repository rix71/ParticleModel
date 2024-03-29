# ParticleModel


## Installing

Download the code using:

```
git clone https://github.com/rix71/ParticleModel.git
```

Or do a recursive clone, if you want the postprocessor as well.

**NB! The postprocessor is still a work-in-progress.** Better use your own scripts for now.

---

Installing is as easy as:

```
cd ParticleModel/code
make
```

If you change nothing in the `Makefile`, your executable should be in `particle_model/bin` directory.

### But...

Before running `make`, have a look at the `Makefile` and `include/output.h` files.

- Comment/uncomment compiler flags in `Makefile` to disable/enable e.g., openMP, debug features or select the biofouling model (only "simple" implemented at the moment).
- Select output variables by commenting/uncommenting lines in `include/output.h`. Particle position will always be written.

## TODO

See TODO.txt for known issues/ideas for further development. 
