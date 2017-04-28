package org.corfudb.logReader;

import io.netty.buffer.ByteBuf;
import io.netty.buffer.ByteBufAllocator;
import org.corfudb.format.Types;
import org.corfudb.infrastructure.log.StreamLogFiles;
import org.corfudb.infrastructure.log.LogAddress;
import static org.junit.Assert.*;

import org.corfudb.protocols.wireprotocol.DataType;
import org.corfudb.protocols.wireprotocol.LogData;
import org.corfudb.util.serializer.Serializers;
import org.docopt.DocoptExitException;
import org.junit.After;
import org.junit.Before;
import org.junit.Test;

import java.io.File;
import java.io.IOException;
import java.util.UUID;

/**
 * Created by kjames88 on 3/1/17.
 */

public class logReaderTest {
    public static String LOGBASEPATH = "/tmp/corfu-test";
    public static String LOGPATH = LOGBASEPATH + "/log";

    @Before
    public void setUp() {
        testUUID = UUID.randomUUID();
        File fDir = new File(LOGPATH);
        fDir.mkdirs();
        StreamLogFiles logfile = new StreamLogFiles(LOGPATH, false);
        ByteBuf buf = ByteBufAllocator.DEFAULT.buffer();
        Serializers.CORFU.serialize("Hello World".getBytes(), buf);
        LogData data = new LogData(DataType.DATA, buf);
        logfile.append(new LogAddress(new Long(0), testUUID), data);
        buf.clear();
        Serializers.CORFU.serialize("Happy Days".getBytes(), buf);
        data = new LogData(DataType.DATA, buf);
        logfile.append(new LogAddress(new Long(1), testUUID), data);
        buf.clear();
        Serializers.CORFU.serialize("Corfu test".getBytes(), buf);
        data = new LogData(DataType.DATA, buf);
        logfile.append(new LogAddress(new Long(2), testUUID), data);
        logfile.close();
    }
    @After
    public void tearDown() {
        File fDir = new File(LOGPATH);
        String[] files = fDir.list();
        for (String f : files) {
            File f_del = new File(LOGPATH + "/" + f);
            f_del.delete();
        }
        fDir.delete();
        fDir = new File(LOGBASEPATH);
        fDir.delete();
    }
    @Test(expected = DocoptExitException.class)
    public void TestArgumentsRequired() {
        logReader reader = new logReader();
        String[] args = {};
        boolean ret = reader.init(args);
        assertEquals(false, ret);
    }
    @Test
    public void TestRecordCount() {
        final int totalRecordCnt = 3;

        logReader reader = new logReader();
        String[] args = {"report", LOGPATH + "/" + testUUID + "-0.log"};
        int cnt = reader.run(args);
        assertEquals(totalRecordCnt, cnt);
    }
    @Test
    public void TestDisplayOne() {
        logReader reader = new logReader();
        String[] args = {"display", "--from=1", "--to=1", LOGPATH + "/" + testUUID + "-0.log"};
        reader.init(args);
        try {
            reader.openLogFile(0);
            LogEntryExtended e = reader.nextRecord();
            assertEquals(null, e);
            e = reader.nextRecord();
            assertNotEquals(null, e);
            e = reader.nextRecord();
            assertEquals(null, e);
        } catch (IOException e) {
            e.printStackTrace();
            fail();
        }
    }
    @Test
    public void TestDisplayAll() {
        logReader reader = new logReader();
        String[] args = {"display", "--from=0", "--to=2", LOGPATH + "/" + testUUID + "-0.log"};
        reader.init(args);
        try {
            reader.openLogFile(0);
            LogEntryExtended e = reader.nextRecord();
            assertNotEquals(null, e);
            e = reader.nextRecord();
            assertNotEquals(null, e);
            e = reader.nextRecord();
            assertNotEquals(null, e);
        } catch (IOException e) {
            e.printStackTrace();
            fail();
        }
    }
    @Test
    public void TestEraseOne() {
        logReader reader = new logReader();
        String[] args = {"erase", "--from=1", "--to=1", LOGPATH + "/" + testUUID + "-0.log"};
        reader.run(args);

        // Read back the new modified log file and confirm the expected change
        reader = new logReader();
        args = new String[]{"display", LOGPATH + "/" + testUUID + "-0.log.modified"};
        reader.init(args);
        try {
            reader.openLogFile(0);
            LogEntryExtended e = reader.nextRecord();
            assertEquals(Types.DataType.DATA, e.getEntryBody().getDataType());
            e = reader.nextRecord();
            assertEquals(Types.DataType.HOLE, e.getEntryBody().getDataType());
            e = reader.nextRecord();
            assertEquals(Types.DataType.DATA, e.getEntryBody().getDataType());
        } catch (IOException e) {
            e.printStackTrace();
            fail();
        }
    }
    @Test
    public void TestEraseTail() {
        logReader reader = new logReader();
        String[] args = {"erase", "--from=1", LOGPATH + "/" + testUUID + "-0.log"};
        reader.run(args);

        // Read back the new modified log file and confirm the expected change
        reader = new logReader();
        args = new String[]{"display", LOGPATH + "/" + testUUID + "-0.log.modified"};
        reader.init(args);
        try {
            reader.openLogFile(0);
            LogEntryExtended e = reader.nextRecord();
            assertEquals(Types.DataType.DATA, e.getEntryBody().getDataType());
            e = reader.nextRecord();
            assertEquals(Types.DataType.HOLE, e.getEntryBody().getDataType());
            e = reader.nextRecord();
            assertEquals(Types.DataType.HOLE, e.getEntryBody().getDataType());
        } catch (IOException e) {
            e.printStackTrace();
            fail();
        }
    }
    private UUID testUUID;
}