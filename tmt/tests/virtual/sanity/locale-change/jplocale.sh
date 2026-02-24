#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k

. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart
  rlPhaseStartSetup
    rlRun "git clone \"$REPO_URL\" repo"
    rlRun "pushd repo"
    rlRun "git fetch origin \"$PR_HEAD\""
    rlRun "git checkout FETCH_HEAD"
    rlRun "cat /etc/fedora-release"
    rlRun "dnf -y install postgresql16-server glibc-langpack-ja"

    rlRun "autoreconf -vfi" 0 "Building and installing postgresql-setup"
    rlRun "./configure --prefix=/usr"
    rlRun "make"

    # change locale (https://wiki.archlinux.org/title/Locale#Make_locale_changes_immediate)
    rlRun "localectl set-locale LANG=ja_JP.UTF-8" 0 "Changing locale"
    rlRun "unset LANG"
    rlRun "source /etc/profile.d/lang.sh"
    rlRun "locale"

    rlRun "PGSETUP_INITDB_OPTIONS=\"--lc-time=C.UTF-8\" ./bin/postgresql-setup --init" 0 "Initializing database dir"
    rlRun "systemctl start postgresql" 0 "Starting service"
    rlRun "systemctl is-active postgresql" 0 "Verifying service running"
  rlPhaseEnd

  rlPhaseStartTest
    rlRun "su - postgres -c \"
    createdb testdb;
    psql -U postgres -d testdb -c \\\"create table users (id serial primary key, name text)\\\";
    psql -U postgres -d testdb -c \\\"insert into users (name) values ('Alice'), ('Bob'), ('Celine')\\\"
    \""
    rlRun "su - postgres -c '
    psql -U postgres -d testdb -c \"select * from users\"
    ' > expected.txt"

    echo "Expected:"
    cat expected.txt
    rlAssertGrep "iso, mdy" /var/lib/pgsql/data/postgresql.conf
    rlFileSubmit /var/lib/pgsql/data/postgresql.conf first.conf


    rlRun "dnf -y remove postgresql16*" 0 "Removing postgresql 16"
    rlRun "dnf -y install postgresql17-upgrade" 0 "Installing postgresql 17"
    rlRun "./bin/postgresql-setup --upgrade" 0 "Running upgrade"

    rlRun "systemctl start postgresql" 0 "Starting service again"
    rlRun "systemctl is-active postgresql" 0 "Verifying service running"

    rlRun "su - postgres -c '
    psql -U postgres -d testdb -c \"select * from users\"
    ' > actual17.txt"

    echo "Actual:"
    cat actual17.txt

    rlAssertNotDiffer expected.txt actual17.txt
    rlAssertGrep "iso, mdy" /var/lib/pgsql/data/postgresql.conf
    rlFileSubmit /var/lib/pgsql/data/postgresql.conf second.conf
  rlPhaseEnd

  rlPhaseStartCleanup
    rlRun "popd"
    rlRun "rm -rf repo"
    rlRun "echo 'LANG=en_US.UTF-8' > /etc/locale.conf" 0 "Resetting locale"
    rlRun "unset LANG"
    rlRun "source /etc/profile.d/lang.sh"
    rlRun "systemctl stop postgresql" 0 "Stopping postgresql service"
    rlRun "rm -rf /var/lib/pgsql" 0 "Removing database folder"
    rlRun "dnf -y remove postgresql*" 0 "Uninstalling postgresql"
  rlPhaseEnd
rlJournalPrintText
rlJournalEnd
