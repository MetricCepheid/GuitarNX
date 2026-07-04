#---------------------------------------------------------------------------------
.SUFFIXES:
#---------------------------------------------------------------------------------

ifeq ($(strip $(DEVKITPRO)),)
$(error "Please set DEVKITPRO in your environment. export DEVKITPRO=<path to>/devkitpro")
endif

TOPDIR ?= $(CURDIR)
include $(DEVKITPRO)/libnx/switch_rules

#---------------------------------------------------------------------------------
# TARGET is the name of the output
# BUILD is the directory where object files & intermediate files will be placed
# SOURCES is a list of directories containing source code
# DATA is a list of directories containing data files
# INCLUDES is a list of directories containing header files
# ROMFS is the directory containing data to be added to RomFS, relative to the Makefile (Optional)
#
# NO_ICON: if set to anything, do not use icon.
# NO_NACP: if set to anything, no .nacp file is generated.
# APP_TITLE is the name of the app stored in the .nacp file (Optional)
# APP_AUTHOR is the author of the app stored in the .nacp file (Optional)
# APP_VERSION is the version of the app stored in the .nacp file (Optional)
# APP_TITLEID is the titleID of the app stored in the .nacp file (Optional)
# ICON is the filename of the icon (.jpg), relative to the project folder.
#   If not set, it attempts to use one of the following (in this order):
#     - <Project name>.jpg
#     - icon.jpg
#     - <libnx folder>/default_icon.jpg
#
# CONFIG_JSON is the filename of the NPDM config file (.json), relative to the project folder.
#   If not set, it attempts to use one of the following (in this order):
#     - <Project name>.json
#     - config.json
#   If a JSON file is provided or autodetected, an ExeFS PFS0 (.nsp) is built instead
#   of a homebrew executable (.nro). This is intended to be used for sysmodules.
#   NACP building is skipped as well.
#---------------------------------------------------------------------------------TARGET      := $(notdir $(CURDIR))
BUILD       := build
SOURCES     := source source/audio source/jdkmidi source/jdkmidisrc source/ogg source/tremor
INCLUDES    := include source source/audio source/ogg source/tremor
ROMFS       :=

APP_TITLE   := GuitarNX
APP_AUTHOR  := Tijeras94
APP_VERSION := 0.0.2
ICON        := Icon.jpg

#---------------------------------------------------------------------------------
# options for code generation
#---------------------------------------------------------------------------------
ARCH := -march=armv8-a+crc+crypto -mtune=cortex-a57

PORTLIBS := $(DEVKITPRO)/portlibs/switch
LIBNX    := $(DEVKITPRO)/libnx

CFLAGS   += -fPIE -fPIC \
            -I$(CURDIR)/source \
            -I$(PORTLIBS)/include \
            -I$(PORTLIBS)/include/freetype2

CXXFLAGS += -fPIE -fPIC \
            -I$(CURDIR)/source \
            -I$(PORTLIBS)/include \
            -I$(PORTLIBS)/include/freetype2

ASFLAGS  := -g $(ARCH) -fPIE

LDFLAGS  := -specs=$(DEVKITPRO)/libnx/switch.specs \
            -g $(ARCH) \
            -Wl,-Map,$(notdir $*.map) \
            -pie -Wl,-pie -Wl,-z,notext

LIBS     := -lSDL2 -lSDL2_mixer -lSDL2_image -lSDL2_ttf \
            -lEGL -lGLESv2 -lglad -lglapi \
            -ldrm_nouveau \
            -lfreetype -lharfbuzz -lpng -lz -lbz2 \
            -lnx

#---------------------------------------------------------------------------------
# list of directories containing libraries, this must be the top level containing
# include and lib
#---------------------------------------------------------------------------------
LIBDIRS  := $(PORTLIBS) $(LIBNX)


#---------------------------------------------------------------------------------
# no real need to edit anything past this point unless you need to add additional
# rules for different file extensions
#---------------------------------------------------------------------------------
ifneq ($(BUILD),$(notdir $(CURDIR)))
#---------------------------------------------------------------------------------

export OUTPUT   := $(CURDIR)/$(TARGET)
export TOPDIR   := $(CURDIR)
export VPATH    := $(foreach dir,$(SOURCES),$(CURDIR)/$(dir))

export DEPSDIR  := $(CURDIR)/$(BUILD)

CFILES   := $(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.c)))
CPPFILES := $(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.cpp)))
SFILES   := $(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.s)))

#---------------------------------------------------------------------------------
# use CXX for linking C++ projects, CC for standard C
#---------------------------------------------------------------------------------
ifeq ($(strip $(CPPFILES)),)
export LD := $(CC)
else
export LD := $(CXX)
endif

export OFILES_SRC := $(CPPFILES:.cpp=.o) $(CFILES:.c=.o) $(SFILES:.s=.o)
export OFILES     := $(OFILES_SRC)

export INCLUDE := \
    $(foreach dir,$(INCLUDES),-I$(CURDIR)/$(dir)) \
    $(foreach dir,$(LIBDIRS),-I$(dir)/include) \
    -I$(CURDIR)/$(BUILD)

export LIBPATHS := $(foreach dir,$(LIBDIRS),-L$(dir)/lib)

#---------------------------------------------------------------------------------
# Icon / metadata
#---------------------------------------------------------------------------------
export APP_ICON := $(TOPDIR)/$(ICON)

ifeq ($(strip $(NO_ICON)),)
export NROFLAGS += --icon=$(APP_ICON)
endif

ifeq ($(strip $(NO_NACP)),)
export NROFLAGS += --nacp=$(CURDIR)/$(TARGET).nacp
endif

ifneq ($(ROMFS),)
export NROFLAGS += --romfsdir=$(CURDIR)/$(ROMFS)
endif

#---------------------------------------------------------------------------------
# main targets
#---------------------------------------------------------------------------------
.PHONY: all clean

all: $(BUILD)

$(BUILD):
	@[ -d $@ ] || mkdir -p $@
	@$(MAKE) --no-print-directory -C $(BUILD) -f $(CURDIR)/Makefile

clean:
	@echo clean ...
	@rm -rf $(BUILD) $(TARGET).nro $(TARGET).elf $(TARGET).nacp

else

export NACPFLAGS	:=	--title "$(APP_TITLE)" --author "$(APP_AUTHOR)" --version "$(APP_VERSION)"

DEPENDS := $(OFILES:.o=.d)

all: $(OUTPUT).nro

$(OUTPUT).nro: $(OUTPUT).elf $(OUTPUT).nacp

$(OUTPUT).elf: $(OFILES)
	@echo linking $(notdir $@)
	@$(LD) $(LDFLAGS) $(LIBPATHS) $^ $(LIBS) -o $@

$(OUTPUT).nacp:
	@echo creating $(notdir $@)
	@nacptool --create "$(APP_TITLE)" "$(APP_AUTHOR)" "$(APP_VERSION)" $@ $(NACPFLAGS)

%.o: %.cpp
	@echo $(notdir $<)
	@$(CXX) -MMD -MP -MF $(DEPSDIR)/$*.d $(ARCH) $(CXXFLAGS) $(INCLUDE) -c $< -o $@

%.o: %.c
	@echo $(notdir $<)
	@$(CC) -MMD -MP -MF $(DEPSDIR)/$*.d $(ARCH) $(CFLAGS) $(INCLUDE) -c $< -o $@

%.o: %.s
	@echo $(notdir $<)
	@$(AS) $(ASFLAGS) -o $@ $<

%.bin.o %_bin.h : %.bin
	@echo $(notdir $<)
	@$(bin2o)

-include $(DEPENDS)

endif
