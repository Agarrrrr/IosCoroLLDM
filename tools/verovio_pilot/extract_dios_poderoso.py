from pathlib import Path
import extract_salmo150 as reader
OUT=Path('output/verovio_pilot_support/dios_poderoso')
def run():
    reader.OUT=OUT
    reader.STARTS=[[1,4,7],[10,13,15],[17,19,21],[23,25,28],[31,34,37],[40,45,50],[54,58,61],[65,68,71],[73,75,77],[79,81,83],[85,89,93],[96,99,101]]
    reader.LYRIC_FONT='TimesNewRomanPSMT';reader.LYRIC_SIZE=13.02
    reader.USE_TUPLET_MARKERS=False
    reader.RESTS['≈']=.25
    reader.key_signature=lambda m:-4 if m>=79 else -3
    reader.extract()
if __name__=='__main__':run()
