#ifndef _JDKMIDI_FILEWRITEMULTITRACK_H
#define _JDKMIDI_FILEWRITEMULTITRACK_H

#include "filewrite.h"
#include "multitrack.h"

namespace jdkmidi
{
  
  class MIDIFileWriteMultiTrack
    {
    public:
      
      MIDIFileWriteMultiTrack(
        const MIDIMultiTrack *mlt_,
        MIDIFileWriteStream *strm_
        );
      
      virtual ~MIDIFileWriteMultiTrack();
      
      bool Write( int num_tracks, int division );
    private:
      
      virtual bool PreWrite();
      virtual bool PostWrite();
      
      MIDIFileWrite writer;
      const MIDIMultiTrack *multitrack;
    };
  
}


#endif
