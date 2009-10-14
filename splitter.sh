echo node,date,r/s,w/s,kr/s,kw/s,wait,actv,svc_t,%w,%b > iostat.txt
cat solstats* | grep solaris_iostat | cut -f 1,11- -d, >> iostat.txt

echo node,date,minf,mjf,xcal,intr,ithr,csw,icsw,migr,smtx,srw,syscl,usr,sys,wt,idl > mpstat.txt
cat solstats* | grep solaris_mpstat | cut -f 1,17- -d, >> mpstat.txt

echo node,date,rKB/s,wKB/s,rPk/s,wPk/s,rAvs,wAvs,Util,Sat > nistat.txt
cat solstats* | grep solaris_nistat | cut -f 1,10- -d, >> nistat.txt

echo node,date,pid,username,size,rss,state,pri,nice,time,cpu,process/nlwp > prstat.txt
cat solstats* | grep solaris_prstat | cut -f 1,12- -d, >> prstat.txt

echo node,date,r,b,w,swap,free,re,mf,pi,po,fr,de,sr,f0,lf,lf,rm,in,sy,cs,us,sy,id > vmstat.txt
cat solstats* | grep solaris_vmstat | cut -f 1,24- -d, >> vmstat.txt

echo node,date,pid,cmd > process.txt
cat solstats* | grep solaris_process | cut -f 1,3- -d, >> process.txt
