#!/usr/bin/ruby
# encoding: utf-8
#	= ^ . ^ =
# vim : filetype=ruby

# Library defined thanks to this theory in ruby semantics
# => http://ozmm.org/posts/singin_singletons.html
# => http://blog.bigbinary.com/2012/06/28/extend-self-in-ruby.html
########	require

require 'yaml'
require 'csv'
require 'rubygems'
require 'net/ldap'
require 'digest/sha1'
require 'base64'

########	class

module XNAS
  extend self
  ########	vars

  DEBUG = true

  ########	def

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
    return string.dup.force_encoding("ASCII-8BIT")
  end

  def print_result(ldap)
    if (DEBUG)
      p ldap.get_operation_result unless (ldap.get_operation_result.code == 0)
    else
      p ldap.get_operation_result unless (ldap.get_operation_result.code == 0)
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
    return string.gsub(/[áàÁÀéèÈÉíìÌÍóòÒÓúùÙÚñüÑÜ]/,replacement)
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
    # Remove characters not in the range of \w [a-zA-Z0-9_]
    string = string.split("-").map {|word| word.gsub(/\W/,'')}.join("-")
    return string
  end

  ########  staff

  def staff_load(ldap,filename)

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

    #puts YAML::dump(posix_group_attributes) if (DEBUG)
    ldap.add( :dn => posix_group_dn , :attributes => posix_group_attributes)
    print_result(ldap)

#    return false unless (ldap.get_operation_result == 0 or ldap.get_operation_result == 20)

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

      # Check OpenLDAP return status
      # http://www.openldap.org/doc/admin24/appendix-ldap-result-codes.html
      code = ldap.get_operation_result.code
      case code
        # 0 success
        when 0
          puts "+ " + posixAccountDN

          # If the result is successful add the user to the defined posixGroup and create the homeDirectory
          if (ldap.get_operation_result)
            ldap.add_attribute(posixGroupDN, :memberUid, commonName)

            # Check OpenLDAP return status
            code = ldap.get_operation_result.code
            case code
              # 0 success
              when 0
                puts "/ "+posixGroupDN + " : " + posixGroupAttribute + " << " + commonName
              # 20 attributeOrValueExists
              when 20
                puts "* "+posixGroupDN + " : " + posixGroupAttribute + " << " + commonName + "\t" + "attributeOrValueExists"
              # 53 unwillingToPerform
              else
                ldap.delete( :dn => posixAccountDN )
                puts "! "+posixGroupDN + " : " + posixGroupAttribute + " << " + commonName
                puts "- " + posixAccountDN
            end
          end
        # 20 attributeOrValueExists
        when 20
          puts "* " + posixAccountDN + " << " + commonName + "\t" + "attributeOrValueExists"
        # 53 unwillingToPerform
        else
          puts "! " + posixAccountDN
      end

      number+=1
    end
  end

  ########  profesor

  def profesor_load(ldap,filename)

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

    CSV.foreach(filename) do |row|
      rfc, name, mail = row
      next if rfc == "RFC"
      next if rfc == "SIN"
      name = get_name(strip_accents(name))
      rfc = rfc[0,9]
      mail = fallback_mail if (mail.nil? or mail.empty?)
      profesores[i] = [rfc, name, mail]
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
        :memberuid => rfc
      }

      #puts YAML::dump(posix_account_attributes) if (DEBUG)
      ldap.add( :dn => posix_account_dn , :attributes => posix_account_attributes )
      print_result(ldap)

      # Check OpenLDAP return status
      # http://www.openldap.org/doc/admin24/appendix-ldap-result-codes.html
      case ldap.get_operation_result.code
        # 0 success
        when 0
          puts "+ " + posix_account_dn if (DEBUG)

          # If the result is successful add the user to the defined posixGroup and create the homeDirectory
          if (ldap.get_operation_result.code == 0)
            #puts YAML::dump(posix_group_attributes) if (DEBUG)
            ldap.add( :dn => posix_group_dn , :attributes => posix_group_attributes)
            print_result(ldap)

            # Check OpenLDAP return status
            case ldap.get_operation_result.code
              # 0 success
              when 0
                puts "+ "+posix_group_dn + " : " + posix_group_attribute + " << " + rfc if (DEBUG)
              # 20 attributeOrValueExists
              when 20
                puts "* "+posix_group_dn + " : " + posix_group_attribute + " << " + rfc + "\t" + "attributeOrValueExists"
              # 68 entryAlreadyExists
              when 68
                puts "* "+posix_group_dn + " : " + posix_group_attribute + " << " + rfc + "\t" + "entryAlreadyExists"
            # 53 unwillingToPerform
              else
                puts "! "+posix_group_dn + " : " + posix_group_attribute + " << " + rfc
                # rollback
                ldap.delete( :dn => posix_account_dn )
                ldap.delete( :dn => posix_group_dn )
                puts "- " + posix_account_dn
                puts "- " + posix_group_dn
            end
          end
        # 20 attributeOrValueExists
        when 20
          puts "* " + posix_account_dn + " << " + rfc + "\t" + "attributeOrValueExists"
        # 68 entryAlreadyExists
        when 68
          puts "* " + posix_account_dn + " << " + rfc + "\t" + "entryAlreadyExists"
        # 53 unwillingToPerform
        else
          puts "! " + posix_account_dn
      end

      number+=1
    end

    #puts YAML::dump(profesores) if (DEBUG)

    #  profesores.each do |profesor|
    #    #puts profesor.inspect
    #    #puts YAML::dump(profesor)
    #    puts profesor[1]
    #  end
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
    puts "? #{name} => #{filter}" if (DEBUG && found.length == 0)
    return found[0]
  end

########  materia

  def valid_group(p_name)
    invalid_names = ["POR ASIGNAR PROFESOR","CONTACTAR A LA DIVISION CORRESPONDIENTE GRUPO CANCELADO CANC"]
    invalid_names.each do |n|
      return false if p_name == n
    end
    return true
  end

  def materias_load(ldap,file)

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
      print_result(ldap)

      # Check OpenLDAP return status
      case ldap.get_operation_result.code
        # 0 success
        when 0
          puts "+ " + displayName if (DEBUG)
        # 20 attributeOrValueExists
        when 20
          puts "* " + displayName + " << " + commonName + "\t" + "attributeOrValueExists"
        # 68 entryAlreadyExists
        when 68
          puts "* " + displayName + " << " + commonName + "\t" + "entryAlreadyExists"
        # 53 unwillingToPerform
        else
          puts "! " + displayName
      end

      if (ldap.get_operation_result.code == 0 or ldap.get_operation_result.code == 20)
        rfc = nil
        a = b = nil
        # assign profesor identifier (rfc) to each subject
        profesores.each do |profesor|
          # Normalize strings before comparison
          a = p_name.chomp.upcase.gsub(/\s+/,' ').gsub(/(M\.[ICAG]|L\.A|I\.Q|ING|FIS|MTRO|MRTO|DRA?)\.?$/,"")
          b = profesor[1].chomp.upcase.gsub(/\s+/,' ').gsub(/(M\.[ICAG]|L\.A|I\.Q|ING|FIS|MTRO|MRTO|DRA?)\.?$/,"")
          if (a.start_with?(b))
            rfc = profesor[0][0,9]
            p_name = b
          end
        end

        found = profesor_find(ldap,normalize(p_name),treebase) if (rfc.nil?)
        puts "! (rfc = nil)" + found.inspect if (rfc.nil?)
        # Sinche the returned elements are multivalued, the symbols point to arrays :|
        rfc = found[:uid][0].to_s unless (found.nil? or found[:uid].nil? or found[:uid].empty?)
        p_name = normalize(found[:description][0].to_s) unless (found.nil? or found[:description].nil? or found[:description].empty?)
        bad << i if (rfc.nil? or rfc.empty?)
        #puts row.inspect if (rfc.nil? or rfc.empty?)
        next if (rfc.nil? or rfc.empty?)

        # Put row into array
        materias[i] = [ id, grupo, materia, rfc , p_name ]
        #mat[:id] => { :name => materia , :group => grupo , :rfc => rfc }

        group_of_names_cn = id + "-" + grupo + "-" + rfc
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
        print_result(ldap)

        # Check OpenLDAP return status
        case ldap.get_operation_result.code
          # 0 success
          when 0
            puts "+ " + group_of_names_dn + " << " + rfc if (DEBUG)
          # 20 attributeOrValueExists
          when 20
            puts "* " + group_of_names_dn + " << " + rfc + "\t" + "attributeOrValueExists"
          # 68 entryAlreadyExists
          when 68
            puts "* " + group_of_names_dn + " << " + rfc + "\t" + "entryAlreadyExists"
          # 53 unwillingToPerform
          else
            puts "! " + group_of_names_dn
         end

      end
    end
  end

  def group_find(ldap,m_id,g_id,treebase)
    m_id = normalize(m_id)
    g_id = normalize(g_id)
    filter = "(&(objectClass=groupOfNames)(cn=#{m_id}-#{g_id}-*))"
    puts "? #{m_id}-#{g_id} => #{filter}"
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
        name = profesor[1].chomp.upcase.gsub(/\s+/,' ').gsub(/(M\.[ICAG]|L\.A|I\.Q|ING|FIS|MTRO|MRTO|DRA?)\.?$/,"").split(" ")
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

########  ./alumnos.rb

  def alumnos_load(ldap,file)
  treebase     = "dc=xnas,dc=local"
  account_ou    = "ou=alumnos,ou=users" + "," + treebase
  employee_type = "alumno"
  user_password = "thesis"
  mail = "nobody@localhost"


  current = last = nil

  alumnos = []
  i=0

    CSV.foreach(file) do |row|
      num_cta, name, mail, id_materia, id_grupo = row
      next if num_cta == "CUENTA"
      name = XNAS.normalize(name)
      alumnos[i] = [num_cta, name, mail, id_materia, id_grupo]
      # skip same employeeNumber
      next if num_cta == last
      i+=1
      common_name  = num_cta
      display_name = XNAS.get_display_name(name)
      last = num_cta

      account_dn = "cn=" + common_name + "," + account_ou
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

      #puts YAML::dump(accountAttributes)
      ldap.add( :dn => account_dn , :attributes => account_attributes )
      XNAS.print_result(ldap)

      # Check OpenLDAP return status
      # http://www.openldap.org/doc/admin24/appendix-ldap-result-codes.html
      case ldap.get_operation_result.code
        # 0 success
        when 0
          puts "+ " + account_dn
        # 20 attributeOrValueExists
        when 20
          puts "* " + account_dn + " << " + common_name + "\t" + "attributeOrValueExists"
        # 68 entryAlreadyExists
        when 68
          puts "* " + account_dn + " << " + common_name + "\t" + "entryAlreadyExists"
        # 53 unwillingToPerform
        else
          puts "! " + account_dn
      end

      if (ldap.get_operation_result.code == 0 or ldap.get_operation_result.code == 20)
        # Add account to group when return code is 0 or 20
        group_of_names_dn = XNAS.group_find(ldap,id_materia,id_grupo,treebase)
        group_of_names_attribute = "member"
        #puts YAML::dump([group_of_names_dn , group_of_names_attribute, account_dn])
        unless (group_of_names_dn.nil? or group_of_names_dn.empty?)
          ldap.add_attribute( group_of_names_dn[:dn] , :member , account_dn)
          XNAS.print_result(ldap)
          case ldap.get_operation_result.code
            when 0
              puts "+ " + group_of_names_dn[:dn] + " << " + num_cta
            when 20
              puts "* " + group_of_names_dn[:dn] + " << " + num_cta + "\t" + "attributeOrValueExists"
            when 68
              puts "* " + group_of_names_dn[:dn] + " << " + num_cta + "\t" + "entryAlreadyExists"
            else
              puts "! " + group_of_names_dn[:dn]
          end
        end
      end
    end
  end

end
