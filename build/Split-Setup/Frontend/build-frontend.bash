#!/bin/bash
# +--------------------------------------------------------------------+
# EFA Frontend alpha1
# +--------------------------------------------------------------------+
# Copyright (C) 2013~2015 https://efa-project.org
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
# +--------------------------------------------------------------------

# +---------------------------------------------------+
# Variables
# +---------------------------------------------------+
version="FE-3.0.0.8"  # Alpha1
logdir="/var/log/EFA"
password="EfaPr0j3ct"
mirror="http://dl.efa-project.org"
mirrorpath="/build/$version"
SPAMASSASSINVERSION="3.4.0a"
PYZORVERSION="0.7.0"
# +---------------------------------------------------+

# +---------------------------------------------------+
# Pre-build
# +---------------------------------------------------+
func_prebuild () {
    # mounting /tmp without nosuid and noexec while building as it breaks building some components.
    mount -o remount rw /tmp
}
# +---------------------------------------------------+

# +---------------------------------------------------+
# Update system before we start
# +---------------------------------------------------+
func_upgradeOS () {
    yum -y upgrade
}
# +---------------------------------------------------+

# +---------------------------------------------------+
# add EFA Repo
# +---------------------------------------------------+
func_efarepo () {
   cd /etc/yum.repos.d/
   /usr/bin/wget --no-check-certificate $mirror/rpm/EFA.repo
   yum install -y unrar perl-IP-Country perl-Mail-SPF-Query perl-Net-Ident perl-Mail-ClamAV
}
# +---------------------------------------------------+

# +---------------------------------------------------+
# add epel repository
# +---------------------------------------------------+
func_epelrepo () {
   rpm --import https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-6
   yum install epel-release -y
   yum install -y tnef perl-BerkeleyDB perl-Convert-TNEF perl-Filesys-Df perl-File-Tail perl-IO-Multiplex perl-Net-Server perl-Net-CIDR perl-File-Tail perl-Net-Netmask perl-NetAddr-IP re2c
}
# +---------------------------------------------------+

# +---------------------------------------------------+
# configure postfix
# +---------------------------------------------------+
func_postfix () {
    mkdir /etc/postfix/ssl
    echo /^Received:/ HOLD>>/etc/postfix/header_checks
    postconf -e "inet_protocols = ipv4"
    postconf -e "inet_interfaces = all"
    postconf -e "mynetworks = 127.0.0.0/8"
    postconf -e "header_checks = regexp:/etc/postfix/header_checks"
    postconf -e "myorigin = \$mydomain"
    postconf -e "mydestination = \$myhostname, localhost.\$mydomain, localhost"
    postconf -e "relay_domains = hash:/etc/postfix/transport"
    postconf -e "transport_maps = hash:/etc/postfix/transport"
    postconf -e "local_recipient_maps = "
    postconf -e "smtpd_helo_required = yes"
    postconf -e "smtpd_delay_reject = yes"
    postconf -e "disable_vrfy_command = yes"
    postconf -e "virtual_alias_maps = hash:/etc/postfix/virtual"
    postconf -e "alias_maps = hash:/etc/aliases"
    postconf -e "alias_database = hash:/etc/aliases"
    postconf -e "default_destination_recipient_limit = 1"
    # SASL config
    postconf -e "broken_sasl_auth_clients = yes"
    postconf -e "smtpd_sasl_auth_enable = yes"
    postconf -e "smtpd_sasl_local_domain = "
    postconf -e "smtpd_sasl_path = smtpd"
    postconf -e "smtpd_sasl_local_domain = $myhostname"
    postconf -e "smtpd_sasl_security_options = noanonymous"
    postconf -e "smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd"
    postconf -e "smtp_sasl_type = cyrus"
    # tls config
    postconf -e "smtp_use_tls = yes"
    postconf -e "smtpd_use_tls = yes"
    postconf -e "smtp_tls_CAfile = /etc/postfix/ssl/smtpd.pem"
    postconf -e "smtp_tls_session_cache_database = btree:/var/lib/postfix/smtp_tls_session_cache"
    postconf -e "smtp_tls_note_starttls_offer = yes"
    postconf -e "smtpd_tls_key_file = /etc/postfix/ssl/smtpd.pem"
    postconf -e "smtpd_tls_cert_file = /etc/postfix/ssl/smtpd.pem"
    postconf -e "smtpd_tls_CAfile = /etc/postfix/ssl/smtpd.pem"
    postconf -e "smtpd_tls_loglevel = 1"
    postconf -e "smtpd_tls_received_header = yes"
    postconf -e "smtpd_tls_session_cache_timeout = 3600s"
    postconf -e "tls_random_source = dev:/dev/urandom"
    postconf -e "smtpd_tls_session_cache_database = btree:/var/lib/postfix/smtpd_tls_session_cache"
    postconf -e "smtpd_tls_security_level = may"
    # Issue #149 Disable SSL in Postfix
    postconf -e "smtpd_tls_mandatory_protocols = !SSLv2,!SSLv3"
    postconf -e "smtp_tls_mandatory_protocols = !SSLv2,!SSLv3"
    postconf -e "smtpd_tls_protocols = !SSLv2,!SSLv3"
    postconf -e "smtp_tls_protocols = !SSLv2,!SSLv3"
    # restrictions
    postconf -e "smtpd_helo_restrictions =  check_helo_access hash:/etc/postfix/helo_access, reject_invalid_hostname"
    postconf -e "smtpd_sender_restrictions = permit_sasl_authenticated, check_sender_access hash:/etc/postfix/sender_access, reject_non_fqdn_sender, reject_unknown_sender_domain"
    postconf -e "smtpd_data_restrictions =  reject_unauth_pipelining"
    postconf -e "smtpd_client_restrictions = permit_sasl_authenticated, reject_rbl_client zen.spamhaus.org"
    postconf -e "smtpd_recipient_restrictions = permit_sasl_authenticated, permit_mynetworks, reject_unauth_destination, reject_non_fqdn_recipient, reject_unknown_recipient_domain, check_recipient_access hash:/etc/postfix/recipient_access, check_policy_service inet:127.0.0.1:2501"
    postconf -e "masquerade_domains = \$mydomain"
    #other configuration files
    newaliases
    touch /etc/postfix/transport
    touch /etc/postfix/virtual
    touch /etc/postfix/helo_access
    touch /etc/postfix/sender_access
    touch /etc/postfix/recipient_access
    touch /etc/postfix/sasl_passwd
    postmap /etc/postfix/transport
    postmap /etc/postfix/virtual
    postmap /etc/postfix/helo_access
    postmap /etc/postfix/sender_access
    postmap /etc/postfix/recipient_access
    postmap /etc/postfix/sasl_passwd

    # Issue #167 Change perms on /etc/postfix/sasl_passwd to 600
    chmod 0600 /etc/postfix/sasl_passwd

    # Logjam Vulnerability #188
    openssl dhparam -out /etc/postfix/ssl/dhparam.pem 2048
    postconf -e "smtpd_tls_dh1024_param_file = /etc/postfix/ssl/dhparam.pem"
    postconf -e "smtpd_tls_ciphers = low"

    echo "pwcheck_method: auxprop">/usr/lib64/sasl2/smtpd.conf
    echo "auxprop_plugin: sasldb">>/usr/lib64/sasl2/smtpd.conf
    echo "mech_list: PLAIN LOGIN CRAM-MD5 DIGEST-MD5">>/usr/lib64/sasl2/smtpd.conf
}
# +---------------------------------------------------+

# +---------------------------------------------------+
# install and configure MailScanner
# http://mailscanner.info
# +---------------------------------------------------+
func_mailscanner () {
    cd /usr/src/EFA
    wget $mirror/$mirrorpath/MailScanner-4.84.6-1.rpm.tar.gz
    tar -xvzf MailScanner-4.84.6-1.rpm.tar.gz
    cd MailScanner-4.84.6-1
    ./install.sh
    rm -f /root/.rpmmacros
    chown postfix:postfix /var/spool/MailScanner/quarantine
    mkdir /var/spool/MailScanner/spamassassin
    chown postfix:postfix /var/spool/MailScanner/spamassassin
    mkdir /var/spool/mqueue
    chown postfix:postfix /var/spool/mqueue
    touch /var/lock/subsys/MailScanner.off
    touch /etc/MailScanner/rules/spam.blacklist.rules

    # Configure MailScanner
    sed -i '/^Max Children =/ c\Max Children = 2' /etc/MailScanner/MailScanner.conf
    sed -i '/^Run As User =/ c\Run As User = postfix' /etc/MailScanner/MailScanner.conf
    sed -i '/^Run As Group =/ c\Run As Group = postfix' /etc/MailScanner/MailScanner.conf
    sed -i '/^Incoming Queue Dir =/ c\Incoming Queue Dir = \/var\/spool\/postfix\/hold' /etc/MailScanner/MailScanner.conf
    sed -i '/^Outgoing Queue Dir =/ c\Outgoing Queue Dir = \/var\/spool\/postfix\/incoming' /etc/MailScanner/MailScanner.conf
    sed -i '/^MTA =/ c\MTA = postfix' /etc/MailScanner/MailScanner.conf
    # Issue #177 Correct EFA to new clamav paths using EPEL
    sed -i '/^Incoming Work Group =/ c\Incoming Work Group = clam' /etc/MailScanner/MailScanner.conf
    sed -i '/^Incoming Work Permissions =/ c\Incoming Work Permissions = 0644' /etc/MailScanner/MailScanner.conf
    sed -i '/^Quarantine User =/ c\Quarantine User = postfix' /etc/MailScanner/MailScanner.conf
    sed -i '/^Quarantine Group =/ c\Quarantine Group = apache' /etc/MailScanner/MailScanner.conf
    sed -i '/^Quarantine Permissions =/ c\Quarantine Permissions = 0660' /etc/MailScanner/MailScanner.conf
    sed -i '/^Deliver Unparsable TNEF =/ c\Deliver Unparsable TNEF = yes' /etc/MailScanner/MailScanner.conf
    sed -i '/^Maximum Archive Depth =/ c\Maximum Archive Depth = 0' /etc/MailScanner/MailScanner.conf
    sed -i '/^Virus Scanners =/ c\Virus Scanners = clamd' /etc/MailScanner/MailScanner.conf
    sed -i '/^Non-Forging Viruses =/ c\Non-Forging Viruses = Joke\/ OF97\/ WM97\/ W97M\/ eicar Zip-Password' /etc/MailScanner/MailScanner.conf
    sed -i '/^Web Bug Replacement =/ c\Web Bug Replacement = http:\/\/dl.efa-project.org\/static\/1x1spacer.gif' /etc/MailScanner/MailScanner.conf
    sed -i '/^Quarantine Whole Message =/ c\Quarantine Whole Message = yes' /etc/MailScanner/MailScanner.conf
    sed -i '/^Quarantine Infections =/ c\Quarantine Infections = no' /etc/MailScanner/MailScanner.conf
    sed -i '/^Keep Spam And MCP Archive Clean =/ c\Keep Spam And MCP Archive Clean = yes' /etc/MailScanner/MailScanner.conf
    sed -i 's/X-%org-name%-MailScanner/X-%org-name%-MailScanner-EFA/g' /etc/MailScanner/MailScanner.conf
    sed -i '/^Remove These Headers =/ c\Remove These Headers = X-Mozilla-Status: X-Mozilla-Status2: Disposition-Notification-To: Return-Receipt-To:' /etc/MailScanner/MailScanner.conf
    sed -i '/^Disarmed Modify Subject =/ c\Disarmed Modify Subject = no' /etc/MailScanner/MailScanner.conf
    sed -i '/^Send Notices =/ c\Send Notices = no' /etc/MailScanner/MailScanner.conf
    sed -i '/^Notice Signature =/ c\Notice Signature = -- \\nEFA\\nEmail Filter Appliance\\nwww.efa-project.org' /etc/MailScanner/MailScanner.conf
    sed -i '/^Notices From =/ c\Notices From = EFA' /etc/MailScanner/MailScanner.conf
    sed -i '/^Inline HTML Signature =/ c\Inline HTML Signature = %rules-dir%\/sig.html.rules' /etc/MailScanner/MailScanner.conf
    sed -i '/^Inline Text Signature =/ c\Inline Text Signature = %rules-dir%\/sig.text.rules' /etc/MailScanner/MailScanner.conf
    sed -i '/^Is Definitely Not Spam =/ c\Is Definitely Not Spam = &SQLWhitelist' /etc/MailScanner/MailScanner.conf
    sed -i '/^Is Definitely Spam =/ c\Is Definitely Spam = &SQLBlacklist' /etc/MailScanner/MailScanner.conf
    sed -i '/^Definite Spam Is High Scoring =/ c\Definite Spam Is High Scoring = yes' /etc/MailScanner/MailScanner.conf
    sed -i '/^Treat Invalid Watermarks With No Sender as Spam =/ c\Treat Invalid Watermarks With No Sender as Spam = 2' /etc/MailScanner/MailScanner.conf
    sed -i '/^Max SpamAssassin Size =/ c\Max SpamAssassin Size = 100k continue 150k' /etc/MailScanner/MailScanner.conf
    sed -i '/^Required SpamAssassin Score =/ c\Required SpamAssassin Score = 4' /etc/MailScanner/MailScanner.conf
    sed -i '/^Spam Actions =/ c\Spam Actions = store custom(spam)' /etc/MailScanner/MailScanner.conf
    sed -i '/^High Scoring Spam Actions =/ c\High Scoring Spam Actions = store' /etc/MailScanner/MailScanner.conf
    sed -i '/^Non Spam Actions =/ c\Non Spam Actions = store deliver header "X-Spam-Status:No" custom(nonspam)' /etc/MailScanner/MailScanner.conf
    sed -i '/^Log Spam =/ c\Log Spam = yes' /etc/MailScanner/MailScanner.conf
    sed -i '/^Log Silent Viruses =/ c\Log Silent Viruses = yes' /etc/MailScanner/MailScanner.conf
    sed -i '/^Log Dangerous HTML Tags =/ c\Log Dangerous HTML Tags = yes' /etc/MailScanner/MailScanner.conf
    sed -i '/^SpamAssassin Local State Dir =/ c\SpamAssassin Local State Dir = /var/lib/spamassassin' /etc/MailScanner/MailScanner.conf
    sed -i '/^SpamAssassin User State Dir =/ c\SpamAssassin User State Dir = /var/spool/MailScanner/spamassassin' /etc/MailScanner/MailScanner.conf
    sed -i '/^Detailed Spam Report =/ c\Detailed Spam Report = yes' /etc/MailScanner/MailScanner.conf
    sed -i '/^Include Scores In SpamAssassin Report =/ c\Include Scores In SpamAssassin Report = yes' /etc/MailScanner/MailScanner.conf
    sed -i '/^Always Looked Up Last =/ c\Always Looked Up Last = &MailWatchLogging' /etc/MailScanner/MailScanner.conf
    # Issue #177 Correct EFA to new clamav paths using EPEL
    sed -i '/^Clamd Socket =/ c\Clamd Socket = /var/run/clamav/clamd.sock' /etc/MailScanner/MailScanner.conf
    sed -i '/^Log SpamAssassin Rule Actions =/ c\Log SpamAssassin Rule Actions = no' /etc/MailScanner/MailScanner.conf
    sed -i "/^Sign Clean Messages =/ c\# EFA Note: CustomAction.pm will Sign Clean Messages instead using the custom(nonspam) action.\nSign Clean Messages = No" /etc/MailScanner/MailScanner.conf
    sed -i "/^Deliver Cleaned Messages =/ c\Deliver Cleaned Messages = No" /etc/MailScanner/MailScanner.conf
    sed -i "/^Maximum Processing Attempts =/ c\Maximum Processing Attempts = 2" /etc/MailScanner/MailScanner.conf
    sed -i "/^High SpamAssassin Score =/ c\High SpamAssassin Score = 7" /etc/MailScanner/MailScanner.conf

  # Issue #132 Increase sa-learn and spamassassin max message size limits
    sed -i "/^Max Spam Check Size =/ c\Max Spam Check Size = 2048k" /etc/MailScanner/MailScanner.conf

  # Issue #153 Reply signature behavior not functional
    sed -i "/^Dont Sign HTML If Headers Exist =/ c\Dont Sign HTML If Headers Exist = In-Reply-To: References:" /etc/MailScanner/MailScanner.conf

    # Issue #136 Disable Notify Senders by default in MailScanner
    sed -i "/^Notify Senders/ c\Notify Senders = no" /etc/MailScanner/MailScanner.conf

    # Match up envelope header (changed at efa-init but usefull for testing)
    sed -i '/^envelope_sender_header / c\envelope_sender_header X-yoursite-MailScanner-EFA-From' /etc/MailScanner/spam.assassin.prefs.conf

    touch /etc/MailScanner/rules/sig.html.rules
    touch /etc/MailScanner/rules/sig.text.rules
    touch /etc/MailScanner/phishing.safe.sites.conf
    rm -rf /var/spool/MailScanner/incoming
    mkdir /var/spool/MailScanner/incoming
    echo "none /var/spool/MailScanner/incoming tmpfs noatime 0 0">>/etc/fstab
    mount -a

    # Fix (workaround) the "Insecure dependency in open while running with -T switch at /usr/lib64/perl5/IO/File.pm line 185" error
    sed -i '/^#!\/usr\/bin\/perl -I\/usr\/lib\/MailScanner/ c\#!\/usr\/bin\/perl -I\/usr\/lib\/MailScanner\ -U' /usr/sbin/MailScanner

    # Remove all reports except en and modify all texts
    cd /usr/src/EFA/
    wget --no-check-certificate $gitdlurl/MailScanner/reports/en/en-reports-filelist.txt
    rm -rf /etc/MailScanner/reports
    mkdir -p /etc/MailScanner/reports/en
    cd /etc/MailScanner/reports/en
    for report in `cat /usr/src/EFA/en-reports-filelist.txt`
      do
        wget --no-check-certificate $gitdlurl/MailScanner/reports/en/$report
    done

    # Add CustomAction.pm for token handling
    cd /usr/lib/MailScanner/MailScanner/CustomFunctions
    # Remove as a copy will throw a mailscanner --lint error
    rm -f CustomAction.pm
    wget --no-check-certificate $gitdlurl/EFA/CustomAction.pm

    # Add EFA-Tokens-Cron
    cd /etc/cron.daily
    wget --no-check-certificate $gitdlurl/EFA/EFA-Tokens-Cron
    chmod 700 EFA-Tokens-Cron

    # Force mailscanner init to return a code on all failures
    sed -i 's/failure/failure \&\& RETVAL=1/g' /etc/init.d/MailScanner

    # Issue #51 -- Redundant Quarantine Clean Scripts Present
    rm -f /etc/cron.daily/clean.quarantine

    # Remove Mailscanners phishing sites cron (#100, replaced by EFA-MS-Update)
    rm -f /etc/cron.daily/update_phishing_sites

    # Issue #77 -- EFA MailScanner 0 byte tmp files
    cd /usr/lib/MailScanner
    wget --no-check-certificate $gitdlurl/EFA/mailscanner-4.84.6-1.patch
    patch < mailscanner-4.84.6-1.patch
    rm -f mailscanner-4.84.6-1.patch

    # Issue #177 Correct EFA to new clamav paths using EPEL
    sed -i "/^clamav\t\t\/usr\/lib\/MailScanner\/clamav-wrapper/ c\clamav\t\t\/usr\/lib\/MailScanner\/clamav-wrapper\t\/usr" /etc/MailScanner/virus.scanners.conf
    # Future proofing for next MailScanner version...
    sed -i "/^clamav\t\t\/usr\/share\/MailScanner\/clamav-wrapper/ c\clamav\t\t\/usr\/share\/MailScanner\/clamav-wrapper\t\/usr" /etc/MailScanner/virus.scanners.conf
    sed -i "/^clamd\t\t\/bin\/false c\ clamd\t\t\/bin\/false\t\t\t\t\/usr" /etc/MailScanner/virus.scanners.conf
}
# +---------------------------------------------------+

# +---------------------------------------------------+
# Install and configure spamassassin & clamav
# +---------------------------------------------------+
func_spam_clamav () {
    # install clamav and clamd.
    yum -y install clamav clamd

    # Issue #171 Update clamav -- fix any clamav discrepancies

    # Set freshclam to correct paths
    sed -i "/^DatabaseDirectory/ c\DatabaseDirectory /var/lib/clamav" /etc/freshclam.conf
    sed -i "/^DatabaseOwner/ c\DatabaseOwner clam" /etc/freshclam.conf

    # Reverse changes from EPEL version of clamd (superceded by issue #177)
    #sed -i "/^DatabaseDirectory \/var\/lib\/clamav/ c\DatabaseDirectory /var/clamav" /etc/clamd.conf
    #sed -i "/^User clam/ c\User clamav" /etc/clamd.conf
    #rm -rf /var/lib/clamav
    #userdel clam
    #chown clamav:clamav /var/run/clamav
    userdel clamav > /dev/null 2&>1
    rm -f /etc/freshclam.conf.rpmnew

    # remove freshclam from /etc/cron.daily (redundant to /etc/cron.hourly/update_virus_scanners)
    rm -f /etc/cron.daily/freshclam

    # Sane security scripts
    # http://sanesecurity.co.uk/usage/linux-scripts/
    cd /usr/src/EFA
    wget $mirror/$mirrorpath/clamav-unofficial-sigs-3.7.2-EFA-1.0.tar.gz
    tar -xvzf clamav-unofficial-sigs-3.7.2-EFA-1.0.tar.gz
    cd clamav-unofficial-sigs-3.7.2-EFA-1.0
    cp clamav-unofficial-sigs.sh /usr/local/bin/
    cp clamav-unofficial-sigs.conf /usr/local/etc/
    cp clamav-unofficial-sigs.8 /usr/share/man/man8/
    cp clamav-unofficial-sigs-cron /etc/cron.d/
    cp clamav-unofficial-sigs-logrotate /etc/logrotate.d/
    sed -i "/45 \* \* \* \* root / c\45 * * * * root /usr/local/bin/clamav-unofficial-sigs.sh -c /usr/local/etc/clamav-unofficial-sigs.conf >> /var/log/clamav-unofficial-sigs.log 2>&1" /etc/cron.d/clamav-unofficial-sigs-cron
    chmod 755 /usr/local/bin/clamav-unofficial-sigs.sh

    # Issue #177 Correct EFA to new clamav paths using EPEL
    sed -i '/clam_dbs=/ c\clam_dbs="/var/lib/clamav"' /usr/local/etc/clamav-unofficial-sigs.conf

    sed -i '/clamd_pid=/ c\clamd_pid="/var/run/clamav/clamd.pid"' /usr/local/etc/clamav-unofficial-sigs.conf
    sed -i '/#clamd_socket=/ c\clamd_socket="/var/run/clamav/clamd.sock"' /usr/local/etc/clamav-unofficial-sigs.conf
    sed -i '/reload_dbs=/ c\reload_dbs="yes"' /usr/local/etc/clamav-unofficial-sigs.conf
    sed -i '/user_configuration_complete="no"/ c\user_configuration_complete="yes"' /usr/local/etc/clamav-unofficial-sigs.conf

    # Issue #169 Clean up clamav-unoffical-sigs script (superceded)
    # sed -i '/^mbl_dbs="/ c\#mbl_dbs="' /usr/local/etc/clamav-unofficial-sigs.conf
    # sed -i '/^#mbl_dbs="/ {n; s/.*/#  mbl.ndb/}' /usr/local/etc/clamav-unofficial-sigs.conf
    # sed -i '/^#mbl_dbs="/ {n;n; s/.*/#"/}' /usr/local/etc/clamav-unofficial-sigs.conf

    # Issue #45 ScamNailer ClamAV ruleset (superceded -- moved to unofficial-sigs)
    # todo: host this on dl.efa-project.org
    # http://www.scamnailer.info/
    # echo -e "#EFA: ScamNailer ClamAV Ruleset\nDatabaseCustomURL http://www.mailscanner.eu/scamnailer.ndb" >> /etc/freshclam.conf

    # Use the EFA packaged version.
    cd /usr/src/EFA
    wget $mirror/$mirrorpath/Spamassassin-3.4.0a-EFA-Upgrade.tar.gz
    tar -xvzf Spamassassin-3.4.0a-EFA-Upgrade.tar.gz
    cd Spamassassin*
    chmod 755 install.sh
    ./install.sh
    cd /usr/src/EFA
    rm -rf Spamassassin*

    # Symlink for Geo::IP
    mkdir -p /usr/local/share/GeoIP
    ln -s /var/www/html/mailscanner/temp/GeoIP.dat /usr/local/share/GeoIP/GeoIP.dat

    # PDFInfo
    cd /usr/src/EFA
    /usr/bin/wget --no-check-certificate -O /usr/local/share/perl5/Mail/SpamAssassin/Plugin/PDFInfo.pm $gitdlurl/PDFInfo/PDFInfo.pm
    /usr/bin/wget --no-check-certificate -O /etc/mail/spamassassin/pdfinfo.cf $gitdlurl/PDFInfo/pdfinfo.cf
    echo "loadplugin Mail::SpamAssassin::Plugin::PDFInfo">>/etc/mail/spamassassin/v310.pre

    # Download an initial KAM.cf file updates are handled by EFA-SA-Update.
    /usr/bin/wget --no-check-certificate -O /etc/mail/spamassassin/KAM.cf $gitdlurl/EFA/KAM.cf

    # Configure spamassassin bayes and awl DB settings
    echo "#Begin E.F.A. mods for MySQL">>/etc/MailScanner/spam.assassin.prefs.conf
    echo "bayes_store_module              Mail::SpamAssassin::BayesStore::SQL">>/etc/MailScanner/spam.assassin.prefs.conf
    echo "bayes_sql_dsn                   DBI:mysql:sa_bayes:localhost">>/etc/MailScanner/spam.assassin.prefs.conf
    echo "bayes_sql_username              sa_user">>/etc/MailScanner/spam.assassin.prefs.conf
    echo "bayes_sql_password              $password">>/etc/MailScanner/spam.assassin.prefs.conf
    echo "auto_whitelist_factory          Mail::SpamAssassin::SQLBasedAddrList">>/etc/MailScanner/spam.assassin.prefs.conf
    echo "user_awl_dsn                    DBI:mysql:sa_bayes:localhost">>/etc/MailScanner/spam.assassin.prefs.conf
    echo "user_awl_sql_username           sa_user">>/etc/MailScanner/spam.assassin.prefs.conf
    echo "user_awl_sql_password           $password">>/etc/MailScanner/spam.assassin.prefs.conf
    echo "bayes_sql_override_username     mailwatch">>/etc/MailScanner/spam.assassin.prefs.conf
    echo "#End E.F.A. mods for MySQL">>/etc/MailScanner/spam.assassin.prefs.conf

    # Add example spam to db
    # source: http://spamassassin.apache.org/gtube/gtube.txt
    cd /usr/src/EFA
    /usr/bin/wget --no-check-certificate $gitdlurl/EFA/gtube.txt
    /usr/local/bin/sa-learn --spam /usr/src/EFA/gtube.txt

    # Enable Auto White Listing
    sed -i '/^#loadplugin Mail::SpamAssassin::Plugin::AWL/ c\loadplugin Mail::SpamAssassin::Plugin::AWL' /etc/mail/spamassassin/v310.pre

    # AWL cleanup tools (just a bit different then esva)
    # http://notes.sagredo.eu/node/86
    echo '#!/bin/sh'>/usr/sbin/trim-awl
    echo "/usr/bin/mysql -usa_user -p$password < /etc/trim-awl.sql">>/usr/sbin/trim-awl
    echo 'exit 0 '>>/usr/sbin/trim-awl
    chmod +x /usr/sbin/trim-awl

    echo "USE sa_bayes;">/etc/trim-awl.sql
    echo "DELETE FROM awl WHERE ts < (NOW() - INTERVAL 28 DAY);">>/etc/trim-awl.sql

    cd /etc/cron.weekly
    echo '#!/bin/sh'>trim-sql-awl-weekly
    echo '#'>>trim-sql-awl-weekly
    echo '#  Weekly maintenance of auto-whitelist for'>>trim-sql-awl-weekly
    echo '#  SpamAssassin using MySQL'>>trim-sql-awl-weekly
    echo '/usr/sbin/trim-awl'>>trim-sql-awl-weekly
    echo 'exit 0'>>trim-sql-awl-weekly
    chmod +x trim-sql-awl-weekly

    # Create .spamassassin directory (error reported in lint test)
    mkdir /var/www/.spamassassin
    chown postfix:postfix /var/www/.spamassassin

    # Add Sought Channel to replace Sare and initialize sa-update
    /usr/local/bin/sa-update
    /usr/bin/wget --no-check-certificate -O /usr/src/EFA/GPG.KEY $gitdlurl/Sought/GPG.KEY
    /usr/local/bin/sa-update --import /usr/src/EFA/GPG.KEY

    # Customize sa-update in /etc/sysconfig/update_spamassassin
    sed -i '/^SAUPDATE=/ c\SAUPDATE=/usr/local/bin/sa-update' /etc/sysconfig/update_spamassassin
    sed -i '/^SACOMPILE=/ c\SACOMPILE=/usr/local/bin/sa-compile' /etc/sysconfig/update_spamassassin
    sed -i '/^SAUPDATEARGS=/ c\SAUPDATEARGS=" --gpgkey 6C6191E3 --channel sought.rules.yerp.org --channel updates.spamassassin.org"' /etc/sysconfig/update_spamassassin

    # Issue #82 re2c spamassassin rule complilation
    sed -i "/^# loadplugin Mail::SpamAssassin::Plugin::Rule2XSBody/ c\loadplugin Mail::SpamAssassin::Plugin::Rule2XSBody" /etc/mail/spamassassin/v320.pre

    # Issue #168 Start regular updates on RegistrarBoundaries.pm
    # next 2 lines temp until everything is packaged
    cd /usr/src/EFA
    wget $mirror/$mirrorpath/RegistrarBoundaries.pm
    rm -f /usr/local/share/perl5/Mail/SpamAssassin/Util/RegistrarBoundaries.pm
    mv RegistrarBoundaries.pm /usr/local/share/perl5/Mail/SpamAssassin/Util/RegistrarBoundaries.pm

    # and in the end we run sa-update just for the fun of it..
    /usr/local/bin/sa-update --gpgkey 6C6191E3 --channel sought.rules.yerp.org --channel updates.spamassassin.org
    /usr/local/bin/sa-compile

    echo "SPAMASSASSINVERSION:$SPAMASSASSINVERSION" >> /etc/EFA-Config
}
# +---------------------------------------------------+

# +---------------------------------------------------+
# configure SQLgrey
# http://sqlgrey.sourceforge.net/
# +---------------------------------------------------+
func_sqlgrey () {
    cd /usr/src/EFA
    useradd sqlgrey -m -d /home/sqlgrey -s /sbin/nologin
    wget $mirror/$mirrorpath/sqlgrey-1.8.0.tar.gz
    tar -xvzf sqlgrey-1.8.0.tar.gz
    cd sqlgrey-1.8.0
    make rh-install

    # pre-create the local files so users won't be confused if the file is not there.
    touch /etc/sqlgrey/clients_ip_whitelist.local
    touch /etc/sqlgrey/clients_fqdn_whitelist.local

    # Make the changes to the config file...
    sed -i '/conf_dir =/ c\conf_dir = /etc/sqlgrey' /etc/sqlgrey/sqlgrey.conf
    sed -i '/user =/ c\user = sqlgrey' /etc/sqlgrey/sqlgrey.conf
    sed -i '/group =/ c\group = sqlgrey' /etc/sqlgrey/sqlgrey.conf
    sed -i '/confdir =/ c\confdir = /etc/sqlgrey' /etc/sqlgrey/sqlgrey.conf
    sed -i '/connect_src_throttle =/ c\connect_src_throttle = 5' /etc/sqlgrey/sqlgrey.conf
    sed -i "/awl_age = 32/d" /etc/sqlgrey/sqlgrey.conf
    sed -i "/group_domain_level = 10/d" /etc/sqlgrey/sqlgrey.conf
    sed -i '/awl_age =/ c\awl_age = 60' /etc/sqlgrey/sqlgrey.conf
    sed -i '/group_domain_level =/ c\group_domain_level = 2' /etc/sqlgrey/sqlgrey.conf
    sed -i '/db_type =/ c\db_type = mysql' /etc/sqlgrey/sqlgrey.conf
    sed -i '/db_name =/ c\db_name = sqlgrey' /etc/sqlgrey/sqlgrey.conf
    sed -i '/db_host =/ c\db_host = localhost' /etc/sqlgrey/sqlgrey.conf
    sed -i '/db_port =/ c\db_port = default' /etc/sqlgrey/sqlgrey.conf
    sed -i '/db_user =/ c\db_user = sqlgrey' /etc/sqlgrey/sqlgrey.conf
    sed -i "/db_pass =/ c\db_pass = $password" /etc/sqlgrey/sqlgrey.conf
    sed -i '/db_cleandelay =/ c\db_cleandelay = 1800' /etc/sqlgrey/sqlgrey.conf
    sed -i '/clean_method =/ c\clean_method = sync' /etc/sqlgrey/sqlgrey.conf
    sed -i '/prepend =/ c\prepend = 1' /etc/sqlgrey/sqlgrey.conf
    sed -i "/reject_first_attempt\/reject_early_reconnect/d" /etc/sqlgrey/sqlgrey.conf
    sed -i '/reject_first_attempt =/ c\reject_first_attempt = immed' /etc/sqlgrey/sqlgrey.conf
    sed -i '/reject_early_reconnect =/ c\reject_early_reconnect = immed' /etc/sqlgrey/sqlgrey.conf
    sed -i "/reject_code = dunno/d" /etc/sqlgrey/sqlgrey.conf
    sed -i '/reject_code =/ c\reject_code = 451' /etc/sqlgrey/sqlgrey.conf
    sed -i '/whitelists_host =/ c\whitelists_host = sqlgrey.bouton.name' /etc/sqlgrey/sqlgrey.conf
    sed -i '/optmethod =/ c\optmethod = optout' /etc/sqlgrey/sqlgrey.conf

    # start and stop sqlgrey (first launch will create all database tables)
    # We give it 15 seconds to populate the database and then stop it again.
    service sqlgrey start
    sleep 15
    service sqlgrey stop
}
# +---------------------------------------------------+

# +---------------------------------------------------+
# Install Pyzor
# http://downloads.sourceforge.net/project/pyzor/pyzor/0.5.0/pyzor-0.5.0.tar.gz
# +---------------------------------------------------+
func_pyzor () {

    yum -y install python-setuptools

    cd /usr/src/EFA
    wget $mirror/$mirrorpath/pyzor-$PYZORVERSION.tar.gz
    tar xvzf pyzor-$PYZORVERSION.tar.gz
    cd pyzor-$PYZORVERSION
    python setup.py build
    python setup.py install

    # Fix deprecation warning message
    sed -i '/^#!\/usr\/bin\/python/ c\#!\/usr\/bin\/python -Wignore::DeprecationWarning' /usr/bin/pyzor

    mkdir /var/spool/postfix/.pyzor
    ln -s /var/spool/postfix/.pyzor /var/www/.pyzor
    chown -R postfix:apache /var/spool/postfix/.pyzor
    chmod -R ug+rwx /var/spool/postfix/.pyzor

    # and finally initialize the servers file with an discover.
    su postfix -s /bin/bash -c 'pyzor discover'

    # Add version to EFA-Config
    echo "PYZORVERSION:$PYZORVERSION" >> /etc/EFA-Config
}
# +---------------------------------------------------+

# +---------------------------------------------------+
# Install Razor (http://razor.sourceforge.net/)
# +---------------------------------------------------+
func_razor () {
    cd /usr/src/EFA
    wget $mirror/$mirrorpath/razor-agents-2.84.tar.bz2
    tar xvjf razor-agents-2.84.tar.bz2
    cd razor-agents-2.84

    perl Makefile.PL
    make
    make test
    make install

    mkdir /var/spool/postfix/.razor
    ln -s /var/spool/postfix/.razor /var/www/.razor
    chown postfix:apache /var/spool/postfix/.razor
    chmod -R ug+rwx /var/spool/postfix/.razor

    # Issue #157 Razor failing after registration of service
    # Use setgid bit
    chmod ug+s /var/spool/postfix/.razor
}
# +---------------------------------------------------+

# +---------------------------------------------------+
# Install DCC http://www.rhyolite.com/dcc/
# (current version = version 1.3.154, December 03, 2013)
# +---------------------------------------------------+
func_dcc () {
    cd /usr/src/EFA

    wget $mirror/$mirrorpath/dcc-1.3.154.tar.Z
    tar xvzf dcc-1.3.154.tar.Z
    cd dcc-*

    ./configure --disable-dccm
    make install

    ln -s /var/dcc/libexec/cron-dccd /usr/bin/cron-dccd
    ln -s /var/dcc/libexec/cron-dccd /etc/cron.monthly/cron-dccd
    echo "dcc_home /var/dcc" >> /etc/MailScanner/spam.assassin.prefs.conf
    sed -i '/^dcc_path / c\dcc_path /usr/local/bin/dccproc' /etc/MailScanner/spam.assassin.prefs.conf
    sed -i '/^DCCIFD_ENABLE=/ c\DCCIFD_ENABLE=on' /var/dcc/dcc_conf
    sed -i '/^DBCLEAN_LOGDAYS=/ c\DBCLEAN_LOGDAYS=1' /var/dcc/dcc_conf
    sed -i '/^DCCIFD_LOGDIR=/ c\DCCIFD_LOGDIR="/var/dcc/log"' /var/dcc/dcc_conf
    chown postfix:postfix /var/dcc

    cp /var/dcc/libexec/rcDCC /etc/init.d/adcc
    sed -i "s/#loadplugin Mail::SpamAssassin::Plugin::DCC/loadplugin Mail::SpamAssassin::Plugin::DCC/g" /etc/mail/spamassassin/v310.pre
}
# +---------------------------------------------------+

# +---------------------------------------------------+
# imageCerberus to replace fuzzyocr
# http://sourceforge.net/projects/imagecerberus/
# +---------------------------------------------------+
func_imagecerberus () {
    cd /usr/src/EFA
    wget $mirror/$mirrorpath/imageCerberus-v$IMAGECEBERUSVERSION.zip
    unzip imageCerberus-v$IMAGECEBERUSVERSION.zip
    cd imageCerberus-v$IMAGECEBERUSVERSION
    mkdir /etc/spamassassin
    mv spamassassin/imageCerberus /etc/spamassassin/
    rm -f /etc/spamassassin/imageCerberus/imageCerberusEXE
    mv /etc/spamassassin/imageCerberus/x86_64/imageCerberusEXE /etc/spamassassin/imageCerberus/
    rm -rf /etc/spamassassin/imageCerberus/x86_64
    rm -rf /etc/spamassassin/imageCerberus/i386

    mv spamassassin/ImageCerberusPLG.pm /usr/local/share/perl5/Mail/SpamAssassin/Plugin/
    mv spamassassin/ImageCerberusPLG.cf /etc/mail/spamassassin/

    sed -i '/^loadplugin ImageCerberusPLG / c\loadplugin ImageCerberusPLG /usr/local/share/perl5/Mail/SpamAssassin/Plugin/ImageCerberusPLG.pm' /etc/mail/spamassassin/ImageCerberusPLG.cf

    # fix a few library locations
    ln -s /usr/lib64/libcv.so.2.0 /usr/lib64/libcv.so.1
    ln -s /usr/lib64/libhighgui.so.2.0 /usr/lib64/libhighgui.so.1
    ln -s /usr/lib64/libcxcore.so.2.0 /usr/lib64/libcxcore.so.1
    ln -s /usr/lib64/libcvaux.so.2.0 /usr/lib64/libcvaux.so.1

    # Issue 67 default ImageCeberus score
    sed -i "/^score     ImageCerberusPLG0/ c\score     ImageCerberusPLG0     0.0  0.0  0.0  0.0" /etc/mail/spamassassin/ImageCerberusPLG.cf

    # Add the version to EFA-Config
    echo "IMAGECEBERUSVERSION:$IMAGECEBERUSVERSION" >> /etc/EFA-Config
}
# +---------------------------------------------------+

# +---------------------------------------------------+
# Unbound (replaces dnsmasq)
# +---------------------------------------------------+
func_unbound () {
    # old dnsmasq stuff
    #groupadd -r dnsmasq
    #useradd -r -g dnsmasq dnsmasq
    #sed -i '/#listen-address=/ c\listen-address=127.0.0.1' /etc/dnsmasq.conf
    #sed -i '/#user=/ c\user=dnsmasq' /etc/dnsmasq.conf
    #sed -i '/#group=/ c\group=dnsmasq' /etc/dnsmasq.conf
    #sed -i '/#bind-interfaces/ c\bind-interfaces' /etc/dnsmasq.conf
    #sed -i '/#domain-needed/ c\domain-needed' /etc/dnsmasq.conf
    #sed -i '/#bogus-priv/ c\bogus-priv' /etc/dnsmasq.conf
    #sed -i '/#cache-size=/ c\cache-size=1500' /etc/dnsmasq.conf
    #sed -i '/#no-poll/ c\no-poll' /etc/dnsmasq.conf
    #sed -i '/#resolv-file=/ c\resolv-file=/etc/resolv.dnsmasq' /etc/dnsmasq.conf
    #touch /etc/resolv.dnsmasq
    #echo "nameserver 8.8.8.8" >> /etc/resolv.dnsmasq
    #echo "nameserver 8.8.4.4" >> /etc/resolv.dnsmasq
    yum -y install unbound
    # disable ipv6 support in unbound
    sed -i "/^\t# do-ip6: yes/ c\\\tdo-ip6: no" /etc/unbound/unbound.conf

    # disable validator
    sed -i "/^\t# module-config:/ c\\\tmodule-config: \"iterator\"" /etc/unbound/unbound.conf

    echo "forward-zone:" > /etc/unbound/conf.d/forwarders.conf
    echo '  name: "."' >> /etc/unbound/conf.d/forwarders.conf
    echo "  forward-addr: 8.8.8.8" >> /etc/unbound/conf.d/forwarders.conf
    echo "  forward-addr: 8.8.4.4" >> /etc/unbound/conf.d/forwarders.conf
}
# +---------------------------------------------------+

# +---------------------------------------------------+
# kernel settings
# +---------------------------------------------------+
func_kernsettings () {
    sed -i '/net.bridge.bridge-nf-call-/d' /etc/sysctl.conf
    echo -e "# IPv6 \nnet.ipv6.conf.all.disable_ipv6 = 1 \nnet.ipv6.conf.default.disable_ipv6 = 1 \nnet.ipv6.conf.lo.disable_ipv6 = 1" >> /etc/sysctl.conf
    sysctl -q -p
}
# +---------------------------------------------------+

# +---------------------------------------------------+
# enable and disable services
# +---------------------------------------------------+
func_services () {
    # These services we really don't need.
    chkconfig ip6tables off
    chkconfig cpuspeed off
    chkconfig lvm2-monitor off
    chkconfig mdmonitor off
    chkconfig netfs off
    chkconfig smartd off
    chkconfig abrtd off
    chkconfig portreserve off
    # Postfix is launched by MailScanner
    chkconfig postfix off
    # auditd is something for an future release..
    chkconfig auditd off

    # These services we disable for now and enable them after EFA-Init.
    # Most of these are not enabled by default but add them here just to
    # make sure we don't forget them at EFA-Init.
    chkconfig MailScanner off
    chkconfig saslauthd off
    chkconfig crond off
    chkconfig clamd off
    chkconfig sqlgrey off
    chkconfig mailgraph-init off
    chkconfig adcc off
    chkconfig webmin off
    chkconfig unbound off
    chkconfig munin-node off
}
# +---------------------------------------------------+

# +---------------------------------------------------+
# EFA specific customization
# +---------------------------------------------------+
func_efarequirements () {
    # Write version file
    echo "EFA-$version" > /etc/EFA-Version

    # pre-create the EFA update directory
    mkdir -p /var/EFA/update

    # pre-create the EFA backup directory
    mkdir -p /var/EFA/backup
    mkdir -p /var/EFA/backup/KAM

    # pre-create the EFA lib directory
    mkdir -p /var/EFA/lib
    mkdir -p /var/EFA/lib/EFA-Configure

    # pre-create the EFA Trusted Networks Config
    touch /etc/sysconfig/EFA_trusted_networks

    # write issue file
    echo "" > /etc/issue
    echo "------------------------------" >> /etc/issue
    echo "--- Welcome to EFA-$version ---" >> /etc/issue
    echo "------------------------------" >> /etc/issue
    echo "  http://www.efa-project.org  " >> /etc/issue
    echo "------------------------------" >> /etc/issue
    echo "" >> /etc/issue
    echo "First time login: root/EfaPr0j3ct" >> /etc/issue

    # Grab EFA specific scripts/programs
    /usr/bin/wget --no-check-certificate -O /usr/local/sbin/EFA-Init $gitdlurl/EFA/EFA-Init
    chmod 700 /usr/local/sbin/EFA-Init
    /usr/bin/wget --no-check-certificate -O /usr/local/sbin/EFA-Configure $gitdlurl/EFA/EFA-Configure
    chmod 700 /usr/local/sbin/EFA-Configure
    /usr/bin/wget --no-check-certificate -O /usr/local/sbin/EFA-Update $gitdlurl/EFA/EFA-Update
    chmod 700 /usr/local/sbin/EFA-Update
    /usr/bin/wget --no-check-certificate -O /usr/local/sbin/EFA-SA-Update $gitdlurl/EFA/EFA-SA-Update
    chmod 700 /usr/local/sbin/EFA-SA-Update
    /usr/bin/wget --no-check-certificate -O /usr/local/sbin/EFA-MS-Update $gitdlurl/EFA/EFA-MS-Update
    chmod 700 /usr/local/sbin/EFA-MS-Update
    /usr/bin/wget --no-check-certificate -O /usr/local/sbin/EFA-Backup $gitdlurl/EFA/EFA-Backup
    chmod 700 /usr/local/sbin/EFA-Backup

    # Grab the EFA-Configure libraries
    cd /usr/src/EFA/
    wget --no-check-certificate $gitdlurl/EFA/lib-EFA-Configure/libraries-filelist.txt
    for lib in `cat /usr/src/EFA/libraries-filelist.txt`
      do
        /usr/bin/wget --no-check-certificate -O /var/EFA/lib/EFA-Configure/$lib $gitdlurl/EFA/lib-EFA-Configure/$lib
    done
    chmod 600 /var/EFA/lib/EFA-Configure/*

    # Write SSH banner
    sed -i "/^#Banner / c\Banner /etc/banner"  /etc/ssh/sshd_config
    cat > /etc/banner << 'EOF'
       Welcome to E.F.A. (http://www.efa-project.org)

 Warning!

 THIS IS A PRIVATE COMPUTER SYSTEM. It is for authorized use only.
 Users (authorized or unauthorized) have no explicit or implicit
 expectation of privacy.

 Any or all uses of this system and all files on this system may
 be intercepted, monitored, recorded, copied, audited, inspected,
 and disclosed to authorized site and law enforcement personnel,
 as well as authorized officials of other agencies, both domestic
 and foreign.  By using this system, the user consents to such
 interception, monitoring, recording, copying, auditing, inspection,
 and disclosure at the discretion of authorized site personnel.

 Unauthorized or improper use of this system may result in
 administrative disciplinary action and civil and criminal penalties.
 By continuing to use this system you indicate your awareness of and
 consent to these terms and conditions of use.   LOG OFF IMMEDIATELY
 if you do not agree to the conditions stated in this warning.
EOF

    # Compress logs from logrotate
    sed -i "s/#compress/compress/g" /etc/logrotate.conf

  # Set the system as unconfigured
    sed -i '1i\CONFIGURED:NO' /etc/EFA-Config

    # Set EFA-Init to run at first root login:
    sed -i '1i\\/usr\/local\/sbin\/EFA-Init' /root/.bashrc
}
# +---------------------------------------------------+

# +---------------------------------------------------+
# Cron settings
# +---------------------------------------------------+
func_cron () {
    /usr/bin/wget --no-check-certificate -O /etc/cron.daily/EFA-Daily-cron $gitdlurl/EFA/EFA-Daily-cron
    chmod 700 /etc/cron.daily/EFA-Daily-cron
    /usr/bin/wget --no-check-certificate -O /etc/cron.monthly/EFA-Monthly-cron  $gitdlurl/EFA/EFA-Monthly-cron
    chmod 700 /etc/cron.monthly/EFA-Monthly-cron
    /usr/bin/wget --no-check-certificate -O /etc/cron.daily/EFA-Backup-cron  $gitdlurl/EFA/EFA-Backup-cron
    chmod 700 /etc/cron.daily/EFA-Backup-cron
    # Remove the raid-check util (Issue #102)
    rm -f /etc/cron.d/raid-check
}
# +---------------------------------------------------+

# +---------------------------------------------------+
# Clean-up
# +---------------------------------------------------+
func_cleanup () {
    # Clean SSH keys (generate at first boot)
    /bin/rm -f /etc/ssh/ssh_host_*

    # Secure SSH
    sed -i '/^#PermitRootLogin/ c\PermitRootLogin no' /etc/ssh/sshd_config

    # clear dns entries
    echo "" > /etc/resolv.conf

    # Stop running services to allow kickstart to reboot
    service mysqld stop
    service webmin stop

    # clear source files
    rm -rf /usr/src/EFA/*

    # clean yum cache
    yum clean all

    # clear logfiles
    rm -f /var/log/clamav/freshclam.log
    rm -f /var/log/messages
    touch /var/log/messages
    chmod 600 /var/log/messages
    rm -f /var/log/clamav-unofficial-sigs.log
    rm -f /var/log/cron
    touch /var/log/cron
    chmod 600 /var/log/cron
    rm -f /var/log/dmesg.old
    rm -f /var/log/dracut.log
    rm -f /var/log/httpd/*
    rm -f /var/log/maillog
    touch /var/log/maillog
    chmod 600 /var/log/maillog
    rm -f /var/log/mysqld.log
    touch /var/log/mysqld.log
    chown mysql:mysql /var/log/mysqld.log
    chmod 640 /var/log/mysqld.log
    rm -f /var/log/yum.log
    touch /var/log/yum.log
    chmod 600 /var/log/yum.log
    touch /var/log/clamav/freshclam.log
    chmod 600 /var/log/clamav/freshclam.log
    chown clam:clam /var/log/clamav/freshclam.log
    touch /var/log/clamav/clamd.log
    chmod 600 /var/log/clamav/clamd.log
    chown clam:clam /var/log/clamav/clamd.log

    # Clean root
    rm -f /root/anaconda-ks.cfg
    rm -f /root/install.log
    rm -f /root/install.log.syslog

    # Clean tmp
    rm -rf /tmp/*

    # Clean networking in preparation for creating VM Images
    rm -f /etc/udev/rules.d/70-persistent-net.rules
    echo -e "DEVICE=eth0" > /etc/sysconfig/network-scripts/ifcfg-eth0
    echo -e "BOOTPROTO=dhcp" >> /etc/sysconfig/network-scripts/ifcfg-eth0

    # SELinux is giving me headaches disabling until everything works correctly
    # When everything works we should enable SELinux and try to fix all permissions..
    sed -i '/SELINUX=enforcing/ c\SELINUX=disabled' /etc/selinux/config
    # Fix SE-Linux security issues
    #restorecon -r /var/www
    #chcon -v --type=httpd_sys_content_t /var/lib/mailgraph*
    # todo: figure out which se-linux items needs to be changed to allow clamd access to /var/spool/MailScanner/incoming/*..
    #       Currently se-linux blocks clamd.
    #       (denied  { read } for  pid=4083 comm="clamd" name="3899" dev=tmpfs ino=23882 scontext=unconfined_u:system_r:antivirus_t:s0 tcontext=unconfined_u:object_r:var_spool_t:s0 tclass=dir

    # Remove boot splash so we can see whats going on while booting and set console reso to 800x600
    sed -i 's/\<rhgb quiet\>/ vga=771/g' /boot/grub/grub.conf

    # zero disks for better compression (when creating VM images)
    # this can take a while so disabled for now until we start creating images.
    dd if=/dev/zero of=/filler bs=1000
    rm -f /filler
    dd if=/dev/zero of=/tmp/filler bs=1000
    rm -f /tmp/filler
    dd if=/dev/zero of=/boot/filler bs=1000
    rm -f /boot/filler
    dd if=/dev/zero of=/var/filler bs=1000
    rm -f /var/filler

}
# +---------------------------------------------------+

# +---------------------------------------------------+
# Main logic (this is where we start calling out functions)
# +---------------------------------------------------+
func_prebuild
func_upgradeOS
func_efarepo
func_epelrepo
func_postfix
func_mailscanner
func_spam_clamav
func_sqlgrey
func_pyzor
func_razor
func_dcc
func_imagecerberus
func_unbound
func_kernsettings
func_services
func_efarequirements
func_cron
func_cleanup
# +---------------------------------------------------+