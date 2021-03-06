#!/usr/bin/ruby
# encoding: utf-8
#	= ^ . ^ =
# vim : filetype=ruby

# Library defined thanks to this theory in ruby semantics
# => http://ozmm.org/posts/singin_singletons.html
# => http://blog.bigbinary.com/2012/06/28/extend-self-in-ruby.html

# requirements
# aptitude install ruby rubygems
# gem install net-ldap

########	require

require 'yaml'
require 'csv'
require 'rubygems'
require 'net/ldap'
require 'digest/sha1'
require 'base64'
require 'fileutils'
require 'json'

########	class

module XNAS

  extend self

  ########	vars

  VERBOSE = true
  DEBUG   = true

  ########	def

  def valid_status(code)
    valid = false
    valid = true if (code == 0 or code == 20 or code == 68)
    return valid
  end

  def get_name(identifier="")
    return identifier.split(" ").map {|word| word.capitalize}.join(" ")
  end

  def get_common_name(identifier="")
    # Remove all accents and spaces from name to convert to cn
    identifier = strip_accents(identifier)
    return identifier.gsub(/\ /,'-').downcase
  end

  def get_display_name(identifier="")
    # Convert name to "Sentence Case" including accents and special chars
    identifier = strip_accents(identifier)
    return identifier.split(" ").map {|word| word.capitalize}.join(" ")
  end

  def get_ascii_string(string="")
    # http://stackoverflow.com/questions/1268289/how-to-get-rid-of-non-ascii-characters-in-ruby
    return string.dup.force_encoding("ASCII-8BIT")
  end

  def print_result(code,display_name,index="",group="")
    index = " << " + index unless (index.empty?)
    group = " : " + group unless (group.empty?)
    # Check OpenLDAP return status
    case code
      # 0 success
      when 0
        puts "+ " + display_name + group + index if (DEBUG)
      # 20 attributeOrValueExists
      when 20
        puts "* " + display_name + group + index + "\t" + "attributeOrValueExists" if (VERBOSE)
      # 68 entryAlreadyExists
      when 68
        puts "* " + display_name + group + index + "\t" + "entryAlreadyExists" if (VERBOSE)
      # 21 unknownResult
      # 53 unwillingToPerform
      else
        puts "! " + display_name + group + index
    end
  end

  # normalization functions

  def strip_accents(string="")
    replacement =
    {
      'á' => 'a','à' => 'a','Á' => 'A','À' => 'A',
      'é' => 'e','è' => 'e','È' => 'E','É' => 'E',
      'í' => 'i','ì' => 'i','Ì' => 'I','Í' => 'I',
      'ó' => 'o','ò' => 'o','Ò' => 'O','Ó' => 'O',
      'ú' => 'u','ù' => 'u','Ù' => 'U','Ú' => 'U',
      'ñ' => 'n','Ñ' => 'N','ü' => 'u','Ü' => 'U'
    }
    string = string.gsub(/[áàÁÀéèÈÉíìÌÍóòÒÓúùÙÚñüÑÜ]/,replacement)

    # Remove characters not in the range of \w [a-zA-Z0-9_]
    # 20 (space)
    # 2D -
    # 41-5A [A-Z]
    # 5F _
    # 61-7A [a-z]
    #string = string.gsub(/[\x00-\x1A]|[\x21-\x2C]|[\x2E-\x40]|[\x5B-\x5E]|[\x60]|[\x7B-\x7F]/,"")

    return string
  end

  def strip_title_tag(string="")
    return string.chomp.upcase.gsub(/\s+/,' ').gsub(/(M\.[ICAG]|L\.A|I\.Q|ING|FIS|MTRO|MRTO|DRA?)\.?$/,"")
  end

  def normalize(string)
    # Remove <CR> or <CR><LF>
    string = string.chomp
    # Remove leading and trailing space characters and also compact white spaces
    string = string.gsub(/(^\s+)|(\s+$)/,'').gsub(/\s+/,' ')
    # Strip title tag
    string = strip_title_tag(string)
    # strip punctuation signs
    string = string.gsub(/[.,]/,'')
    # Convert spaces into dashes
    string = string.gsub(/\ /,'-')
    # Replace accented letters with [[:alpha:]] chars
    string = strip_accents(string).downcase
    string = get_ascii_string(string)
    string = string.split("-").map {|word| word.gsub(/\W/,'')}.join("-")
    return string
  end

  def different(filename,except=[])
    id = nil
    items = []
    i = t = 0
    CSV.foreach(filename) do |row|
      id = row[0]
      next if except.include?(id)
      unless items.include?(id)
       items[i] = id
       #puts id if (DEBUG)
        i+=1
      end
      t+=1
    end
    return [i,t]
  end

  ########	staff

  def staff_load(ldap,filename,out,err)
    number = 10000
    treebase       = "dc=xnas,dc=local"
    posixAccountOU = "ou=staff,ou=users" + "," + treebase
    posixGroupDN = "cn=support,ou=unix,ou=groups" + "," + treebase
    posixGroupAttribute = "memberUid"
    homeDirectoryPrefix     = "/opt/xNAS/files/staff/"
    loginShell = "/bin/bash"
    employeeType = "staff"
    userPassword = "thesis"
    gidNumber = "10000"
    staff = []
    i=0

    output = open(out,'w')
    output.truncate(0)
    output.write("usuario,Nombre,correo,CURP\n")

    failed = open(err,'w')
    failed.truncate(0)
    failed.write("usuario,Nombre,correo,CURP\n")

    directories = open("mkdir.log","w+")
    directories.truncate(0)

    posix_group_dn = "cn=support,ou=unix,ou=groups" + "," + treebase
    posix_group_attributes =
    {
        :objectclass =>
      [
        "top" ,
        "posixGroup"
      ] ,
      :cn => "support" ,
      :gidNumber => number.to_s() ,
    }

    ldap.add( :dn => posix_group_dn , :attributes => posix_group_attributes)
    print_result(ldap,posix_group_dn)
    puts ldap.get_operation_result.inspect
    return false unless (valid_status(ldap.get_operation_result.code))

    number+=1
    CSV.foreach(filename) do |row|
      username , name , mail , curp = row
      next if username == "usuario"
      name = name.split(" ").map {|word| word.capitalize}.join(" ")
      staff[i] = [username , name , mail , curp]
      i+=1
      commonName  = username
      displayName = name

      posixAccountDN = "uid=" + commonName + "," + posixAccountOU
      posixAccountAttributes =
      {
        :objectclass =>
        [
          "top" ,
          "person" ,
          "organizationalPerson" ,
          "inetOrgPerson" ,
          "posixAccount" ,
          "shadowAccount"
        ] ,
        :uid            => commonName ,
        :cn             => commonName ,
        :sn             => "." ,
        :mail           => mail ,
        :description    => displayName ,
        :employeeNumber => curp ,
        :employeeType   => employeeType ,
        :uidNumber      => number.to_s(),
        :gidNumber      => gidNumber ,
        :homeDirectory  => homeDirectoryPrefix + commonName ,
        :loginShell     => loginShell ,
        :userPassword   => userPassword
      }

      ldap.add( :dn => posixAccountDN , :attributes => posixAccountAttributes)
      print_result(ldap.get_operation_result.code,posixAccountDN)

      if (valid_status(ldap.get_operation_result.code))
        ldap.add_attribute(posixGroupDN, :memberUid, commonName)
        print_result(ldap.get_operation_result.code,posixGroupDN,commonName,posixGroupAttribute)
        if (valid_status(ldap.get_operation_result.code))
          mkdir(directories,"/opt/xNAS/files","staff",commonName)
        else
          # rollback
          ldap.delete( :dn => posixAccountDN )
        end
      end

      number+=1
    end
    output.close
    failed.close
    directories.close
  end

  ########	profesor

  def profesor_load(ldap,filename,out,err)
    number = 20000 + 1

    treebase       = "dc=xnas,dc=local"
    posix_account_ou = "ou=profesores,ou=users" + "," + treebase
    posix_group_ou = "ou=unix,ou=groups" + "," + treebase
    posix_group_attribute = "memberUid"
    home_prefix     = "/opt/xNAS/files/profesor/"
    login_shell = "/usr/sbin/nologin"
    employee_type = "profesor"
    user_password = "thesis"
    gid_number = number
    fallback_mail = "nobody@localhost"

    profesores = []
    i=0

    output = open(out,'w')
    output.truncate(0)
    output.write("RFC,NOMBRE,mail\n")

    failed = open(err,'w')
    failed.truncate(0)
    failed.write("RFC,NOMBRE,mail\n")

    CSV.foreach(filename) do |row|
      rfc, name, mail = row
      next if rfc == "RFC"
      next if rfc == "SIN"
      name = get_name(strip_accents(name))
      rfc = rfc[0,10]
      mail = fallback_mail if (mail.nil? or mail.empty?)
      if /\W/.match(name.gsub(/[\s_-]+/,""))
        posix_account_dn = "uid=" + rfc + "," + posix_account_ou
        print_result(-1,posix_account_dn,rfc)
        failed.write([ rfc , name , mail ].join(",")+"\n")
        next
      end
      profesores[i] = [rfc, name, mail]
      output.write(profesores[i].join(",")+"\n")
      i+=1

      common_name = get_common_name(name)
      displayName = get_display_name(name)

      posix_account_dn = "uid=" + rfc + "," + posix_account_ou
      posix_account_attributes =
      {
        :objectclass =>
        [
          "top" ,
          "person" ,
          "organizationalPerson" ,
          "inetOrgPerson" ,
          "posixAccount" ,
          "shadowAccount"
        ] ,
        :uid            => rfc ,
        :cn             => normalize(name) ,
        :sn             => "." ,
        :mail           => mail ,
        :description    => displayName ,
        :employeeType   => employee_type ,
        :uidNumber      => number.to_s(),
        :gidNumber      => gid_number.to_s() ,
        :homeDirectory  => home_prefix + common_name ,
        :loginShell     => login_shell ,
        :userPassword   => user_password
      }

      posix_group_dn = "cn=" + rfc + "," + posix_group_ou
      posix_group_attributes =
      {
          :objectclass =>
        [
          "top" ,
          "posixGroup"
        ] ,
        :cn => rfc ,
        :gidNumber => number.to_s() ,
        :memberuid => [ rfc , "andres" ],
      }

      #puts YAML::dump(posix_account_attributes) if (DEBUG)
      ldap.add( :dn => posix_account_dn , :attributes => posix_account_attributes )
      print_result(ldap.get_operation_result.code,posix_account_dn,rfc)

      if (valid_status(ldap.get_operation_result.code))
        # If the result is successful add the user to the defined posixGroup and create the homeDirectory
#        if (ldap.get_operation_result.code == 0)
          #puts YAML::dump(posix_group_attributes) if (DEBUG)
          ldap.add( :dn => posix_group_dn , :attributes => posix_group_attributes)
          print_result(ldap.get_operation_result.code,posix_group_dn,rfc,posix_group_attribute)

          # rollback
          unless (valid_status(ldap.get_operation_result.code))
            ldap.delete( :dn => posix_account_dn )
            ldap.delete( :dn => posix_group_dn )
          end
          
          # profesor posixAccount and posixGroup added, we might now add apache rw conf
          conf_rw("/opt/xNAS/files",rfc,common_name)
      end

      number+=1
    end

    #puts YAML::dump(profesores) if (DEBUG)
    #  profesores.each do |profesor|
    #    #puts profesor.inspect
    #    #puts YAML::dump(profesor)
    #    puts profesor[1]
    #  end
    output.close
    failed.close
  end

  def profesor_find(ldap,name,treebase)
    name = normalize(name)
    filter = "(&(objectClass=posixAccount)(objectClass=inetOrgPerson)(cn=#{name}*))"
    # Run a tree search of all profesors and map them into a hash
    found = ldap.search(
      :base => "ou=profesores,ou=users" + "," + treebase,
      :filter => filter,
      :attributes => ["dn","uid","description"],
      :return_result => true)
    #puts YAML::dump(found)
    puts "? #{name} => #{filter}" if (VERBOSE)
    #puts "=> #{found}" if (DEBUG)
    return found[0]
  end

  ########	materia

  def valid_group(p_name)
    invalid_names = ["POR ASIGNAR PROFESOR","CONTACTAR A LA DIVISION CORRESPONDIENTE GRUPO CANCELADO CANC"]
    invalid_names.each do |n|
      return false if p_name == n
    end
    return true
  end

  def materias_find(ldap,name,treebase)
    name = normalize(name)
    filter = "(&(objectClass=organizationalRole)(cn=#{name}))"
    # Run a tree search of all profesors and map them into a hash
    found = ldap.search(
      :base => "ou=materias" + "," + treebase,
      :filter => filter,
      :attributes => ["dn","cn","description"],
      :return_result => true)
    $stderr.puts "? #{name} => #{filter}" if (VERBOSE)
    $stderr.puts found.inspect
    return found[0]
  end

  def materias_load(ldap,file,out,err)

    number = 20000 + 1

    treebase       = "dc=xnas,dc=local"
    posix_account_ou = "ou=profesores,ou=users" + "," + treebase
    posix_group_ou = "ou=unix,ou=groups" + "," + treebase
    posix_group_attribute = "memberUid"
    home_prefix     = "/opt/xNAS/files/profesor/"
    login_shell = "/usr/sbin/nologin"
    employee_type = "profesor"
    user_password = "thesis"
    gid_number = number
    fallback_mail = "nobody@localhost"

    profesores = []
    materias = []
    i=0
    bad = []
    current = last = nil

    output = open(out,'w')
    output.truncate(0)
    output.write("ID,GRUPO,MATERIA,RFC,PROFESOR\n")

    failed = open(err,'w')
    failed.truncate(0)
    failed.write("ID,GRUPO,MATERIA,RFC,PROFESOR\n")

    directories = open("mkdir.log","a+")

    # Parse CSV file
    CSV.foreach(file) do |row|
    #CSV.foreach("../materias-fail.csv") do |row|
      # Get row contents
      id, grupo, materia, p_rfc, p_name = row

      p_rfc = "" if (p_rfc.nil? or p_rfc.empty?)

      #puts YAML::dump(row) if (DEBUG)

      # Skip header
      next if id == "ID"
      next unless valid_group(p_name)

      # job control
      last = current
      current = id
#      next if (current == last)

      # Remove all accents and spaces from name to convert to cn
      commonName = get_common_name(materia)

      # Get current DN
      displayName = "cn=" + id + "," + "ou=materias" + "," + treebase

      # Convert name to "Sentence Case" including accents and special chars
      materia = get_display_name(materia)

      materia_attributes =
      {
        :objectclass =>
        [
          "top" ,
          "organizationalRole"
        ] ,
        :cn => id ,
        :description => materia ,
      }

      ldap.add( :dn => displayName , :attributes => materia_attributes)
      print_result(ldap.get_operation_result.code,displayName,commonName)

      if (valid_status(ldap.get_operation_result.code))
        rfc = nil
        a = b = nil
        # assign profesor identifier (rfc) to each subject
        profesores.each do |profesor|
          # Normalize strings before comparison
#          a = p_name.chomp.upcase.gsub(/\s+/,' ').gsub(/(M\.[ICAG]|L\.A|I\.Q|ING|FIS|MTRO|MRTO|DRA?)\.?$/,"")
#          b = profesor[1].chomp.upcase.gsub(/\s+/,' ').gsub(/(M\.[ICAG]|L\.A|I\.Q|ING|FIS|MTRO|MRTO|DRA?)\.?$/,"")
          a = strip_title_tag(p_name)
          b = strip_title_tag(profesor[1])

          if (a.start_with?(b))
            rfc = profesor[0][0,10]
            p_name = b
          end
        end

#        found = profesor_find(ldap,normalize(p_name),treebase) if (rfc.nil?)
        found = profesor_find(ldap,normalize(p_name),treebase)
        # Sinche the returned elements are multivalued, the symbols point to arrays :|
        rfc = found[:uid][0].to_s unless (found.nil? or found[:uid].nil? or found[:uid].empty?)
        p_name = normalize(found[:description][0].to_s) unless (found.nil? or found[:description].nil? or found[:description].empty?)
        bad << i if (rfc.nil? or rfc.empty?)
        failed.write([ id, grupo, materia, rfc , p_name ].join(",")+"\n") if (rfc.nil? or rfc.empty?)
        #puts row.inspect if (rfc.nil? or rfc.empty?)
        next if (rfc.nil? or rfc.empty?)

        # Put row into array
        materias[i] = [ id, grupo, materia, rfc , p_name ]
        #mat[:id] => { :name => materia , :group => grupo , :rfc => rfc }
        output.write(materias[i].join(",")+"\n") unless (materias[i].nil?)
        #group_of_names_cn = id + "-" + grupo + "-" + rfc
        group_of_names_cn = id + "-" + rfc
        #group_of_names_cn = materias[i][3] + "-" + materias[i][0] + "-" + materias[i][1]
        group_of_names_dn = "cn=" + group_of_names_cn + "," + "ou=webdav,ou=groups" + "," + treebase
        group_of_names_attributes =
        {
          :objectClass =>
          [
            "top",
            "groupOfNames"
          ] ,
          :cn => group_of_names_cn ,
          :description => [ rfc , "m" + id , "g" + grupo ] ,
          :owner => "uid="+rfc+",ou=profesores,ou=users,"+treebase,
          # when processing students we must add the "member" attribute via ldap.add
          :member => "uid="+rfc+",ou=profesores,ou=users,"+treebase,
          # relationship wuth the subject
          :seeAlso => displayName,
        }
        i += 1
        #puts YAML::dump([group_of_names_dn , group_of_names_attributes]) if (DEBUG)
        ldap.add( :dn => group_of_names_dn , :attributes => group_of_names_attributes)
        print_result(ldap.get_operation_result.code,group_of_names_dn,rfc)
        
        # materia added so far, we might now add ro config
        #conf_ro("/opt/xNAS/files","#{id}-#{grupo}-#{rfc}",p_name,id,grupo)
        conf_ro("/opt/xNAS/files","#{id}-#{rfc}",p_name,id,grupo)
        mkdir(directories,"/opt/xNAS/files","profesor",p_name,id,grupo)
      end
    end
    output.close
    failed.close
    directories.close
  end

  def group_find(ldap,m_id,treebase)
    m_id = normalize(m_id)
    #g_id = normalize(g_id)
    #filter = "(&(objectClass=groupOfNames)(cn=#{m_id}-#{g_id}-*))"
    filter = "(&(objectClass=groupOfNames)(cn=#{m_id}-*))"
    #puts "? #{m_id}-#{g_id} => #{filter}" if (DEBUG)
    puts "? #{m_id} => #{filter}" if (DEBUG)
    # Run a tree search of all matching elements and map them into a hash
    found = ldap.search(
      :base => "ou=webdav,ou=groups" + "," + treebase,
      :filter => filter,
      :attributes => ["dn","cn","description","seeAlso"],
      :return_result => true)
    return nil if (found.nil? or found.empty?)
    # The first element is the one that maters
    found = found.shift unless (found.nil? or found.empty?)
    puts "> " + found[:dn][0] if (DEBUG)
    r = {}
    found.each do |k,v|
      if (v.length == 1)
        r[k] = v.shift.to_s
      else
        r[k] = v.to_a
      end
    end
    return r
  end

  #puts YAML::dump(bad) if (DEBUG)
  def badish
  # Post process each bad entry to match against the profesor names in a regular expression fashion
    bad.each do |item|
      # unpack
      id      = materias[item][0]
      rfc     = materias[item][3]
      p_name  = materias[item][4]
      #puts materias[item].inspect if (DEBUG)

      #name = []
      profesores.each do |profesor|
        # normalize string and split into words
        #name = profesor[1].chomp.upcase.gsub(/\s+/,' ').gsub(/(M\.[ICAG]|L\.A|I\.Q|ING|FIS|MTRO|MRTO|DRA?)\.?$/,"").split(" ")
        name = strip_title_tag(profesor[1]).split(" ")
        # match the known name against a regular expression
        if (name.length >= 5)
          regex = Regexp.new("^"+name[0]+" "+name[1]+" "+name[2]+" "+name[3]+" "+name[4])
          puts [p_name , name , regex].inspect if (p_name =~ regex)
        end
        if (name.length >= 4)
          regex = Regexp.new("^"+name[0]+" "+name[1]+" "+name[2]+" "+name[3])
          puts [p_name , name , regex].inspect if (p_name =~ regex)
        end
        if (name.length >= 3)
          regex = Regexp.new("^"+name[0]+" "+name[1]+" "+name[2])
          puts [p_name , name , regex].inspect if (p_name =~ regex)
        end
        if (name.length >= 2)
          regex = Regexp.new("^"+name[0]+" "+name[1])
          puts [p_name , name , regex].inspect if (p_name =~ regex)
        end
      end
    end
  end

  ########	alumnos


  def alumnos_load(ldap,file,out,err)
    treebase     = "dc=xnas,dc=local"
    account_ou    = "ou=alumnos,ou=users" + "," + treebase
    employee_type = "alumno"
    user_password = "thesis"
    mail = "nobody@localhost"

    current = last = nil

    alumnos = []
    i=0

    output = open(out,'w')
    output.truncate(0)
    output.write("CUENTA,NOMBRE,CORREO,ASIGNATURA,NUMERO\n")

    failed = open(err,'w')
    failed.truncate(0)
    failed.write("CUENTA,NOMBRE,CORREO,ASIGNATURA,NUMERO\n")
    CSV.foreach(file) do |row|
      num_cta, name, mail, id_materia, id_grupo = row
      next if num_cta == "CUENTA"
      last = current
      current = num_cta
      common_name  = num_cta
      account_dn = "cn=" + common_name + "," + account_ou
      if /\W/.match(strip_accents(name).gsub(/[\s_-]+/,""))
        print_result(-1,account_dn,common_name)
        failed.write([num_cta, name, mail, id_materia, id_grupo,/\W/.match(name.gsub(/[\s_-]+/,""))].join(",")+"\n")
      end
      next if /\W/.match(strip_accents(name).gsub(/[\s_-]+/,""))
      name = normalize(name)
      alumnos[i] = [num_cta, name, mail, id_materia, id_grupo]
      output.write(alumnos[i].join(",")+"\n")
      i+=1

      display_name = get_display_name(name)
      last = num_cta

      account_attributes =
      {
        :objectclass =>
        [
          "top" ,
          "person" ,
          "organizationalPerson" ,
          "inetOrgPerson" ,
          "simpleSecurityObject"
        ] ,
        :cn             => num_cta ,
        :sn             => "." ,
        :mail           => mail ,
        :description    => display_name ,
        :employeeNumber => num_cta ,
        :employeeType   => employee_type ,
        :userPassword   => user_password
      }

      # skip same employeeNumber
      #unless (last == current)
        #puts YAML::dump(accountAttributes)
        ldap.add( :dn => account_dn , :attributes => account_attributes )
        print_result(ldap.get_operation_result.code,account_dn,common_name)
      #end

      if (valid_status(ldap.get_operation_result.code))
        # Add account to group when return code is 0 or 20
        #group_of_names_dn = group_find(ldap,id_materia,id_grupo,treebase)
        group_of_names_dn = group_find(ldap,id_materia,treebase)
        group_of_names_attribute = "member"
        #puts YAML::dump([group_of_names_dn , group_of_names_attribute, account_dn])
        unless (group_of_names_dn.nil? or group_of_names_dn.empty?)
          ldap.add_attribute( group_of_names_dn[:dn] , :member , account_dn)
          print_result(ldap.get_operation_result.code,group_of_names_dn[:dn],num_cta,group_of_names_attribute)
        end
      end
    end
    output.close
    failed.close
  end

  ########	apache

  def conf_ro(prefix,m_group_cn,p_dir,m_dir,g_dir)
    output = "apache_ro.conf"
    output = open(output,'a+')
    output.write("
    # #{m_group_cn} - #{p_dir} - #{m_dir} - #{g_dir}
    <Directory #{prefix}/p/#{p_dir}/#{m_dir}>
      # Inherits Dav On
      #AllowOverride AuthConfig Limit
#      Include extra/ldap-auth-ro.conf
      Satisfy ALL
      Require ldap-group cn=#{m_group_cn},ou=webdav,ou=groups,dc=xnas,dc=local
      <LimitExcept GET OPTIONS PROPFIND>
        Satisfy ALL
        Require ldap-group _
        Order Allow,Deny
        Deny From ALL
      </LimitExcept>
    </Directory>
    ")
    puts "+ [ro]	#{prefix}/p/#{p_dir}/#{m_dir}		#{m_group_cn}" if (VERBOSE)
    # must close file descriptor somehow
  end

  def conf_rw(prefix,p_id,p_dir)
    output = "apache_rw.conf"
    output = open(output,'a+')
    output.write("
    # #{p_id} - #{p_dir}
    <Directory #{prefix}/profesor/#{p_dir}/>
      # Inherits Dav On
      AllowOverride AuthConfig Limit
      Options +Indexes
      Satisfy ALL
      Require ldap-group cn=#{p_id},ou=unix,ou=groups,dc=xnas,dc=local
      <LimitExcept GET OPTIONS PROPFIND>
        Satisfy ALL
        Require ldap-group cn=#{p_id},ou=unix,ou=groups,dc=xnas,dc=local
      </LimitExcept>
    </Directory>
    ")
    puts "+ [rw]	#{prefix}/profesor/#{p_dir}		#{p_id}" if (VERBOSE)
    # must close file descriptor somehow
  end

  ########	home

  def mkdir(output,prefix,type,p_dir,m_id="",g_id="")
    target = "#{prefix}/#{type}/#{p_dir}"
    target = "#{target}/#{m_id}" unless (m_id.nil? or m_id.empty?)
    target = "#{target}/#{g_id}" unless (g_id.nil? or g_id.empty?)
    output.write("mkdir -vp #{target}\n")
    #FileUtils.mkdir_p "#{target}"
    puts "mkdir -vp #{target}" if (VERBOSE)
  end

  ########	json

  def json_jqxtree(input,output)
    output = open(output,'w+')
    output.truncate(0)
    data = []
    #parsed_file = CSV.read($stdin, { :col_sep => "\t" })
    CSV.foreach(input, { :col_sep => "\t" }) do |row|
      # Retrieve elements as returned from command
      level, path, dir = row
      # Iterate on each element of the path
      data << { "id" => path+"/"+dir , "parent" => path , "name" => dir }
    end
    # output JSON payload
    output.write data.to_json
    output.close
  end

  def json_jqxlistmenu(input,output,ldap)
    output = open(output,'w+')
    output.truncate(0)
    data = {}
    #parsed_file = CSV.read($stdin, { :col_sep => "\t" })
    CSV.foreach(input, { :col_sep => "\t" }) do |row|
      # Retrieve elements as returned from command
      level, path, dir = row
      # Split into path elements
      path = path.split("/")
      # Remove first element "."
      path.shift
      # Iterate on each element of the path
      case path.length
        when 0
          # root
        when 1
          # type
          $stderr.puts path[0] if (DEBUG)
          unless (data.has_key? path[0])
             data[path[0]] = {}
          end
        when 2
          # user
          $stderr.puts "  " + path[1] if (DEBUG)
          unless (data[path[0]].include? path[1])
             data[path[0]][path[1]] = {}
          end
        when 3
          # subject
          found = materias_find(ldap,path[2],"dc=xnas,dc=local")
          $stderr.puts "    " + path[2] + "\t" + found[:description][0] if (DEBUG)
          next if (found.nil?)
          if (data[path[0]][path[1]][path[2]].nil?)
             $stderr.puts "      > #{dir}" if (DEBUG)
             data[path[0]][path[1]][path[2]] = {"label"=>found[:description][0],"groups"=>[]}
          end
          data[path[0]][path[1]][path[2]]["groups"] << dir
        # Do nothing if no condition is met
        else
      end
    end
    # output JSON payload
    output.write data.to_json
    output.close
  end

end
