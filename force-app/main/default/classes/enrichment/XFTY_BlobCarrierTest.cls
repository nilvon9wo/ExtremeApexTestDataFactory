/**
 * Proves `XFTY_BlobCarrier` - lifting `Blob` fields over the JSON round-trip.
 * Pure in-memory, no DML/SOQL.
 */
@IsTest
private class XFTY_BlobCarrierTest {

    @IsTest
    static void testCapture_takesBlobFieldsOffTheRecords() {
        // Arrange
        List<SObject> records = new List<SObject>{ new Attachment(Name = 'f', Body = Blob.valueOf('x')) };
        List<Map<String, Object>> noForcedValues = new List<Map<String, Object>>{ new Map<String, Object>() };

        // Act
        Test.startTest();
        List<Map<String, Blob>> captured = XFTY_BlobCarrier.capture(records, noForcedValues);
        Test.stopTest();

        // Assert
        Assert.areEqual('x', captured[0].get('Body').toString());
    }

    @IsTest
    static void testCapture_takesBlobFieldsFromTheForcedValues() {
        // Arrange
        List<SObject> records = new List<SObject>{ new Attachment(Name = 'f') };
        List<Map<String, Object>> forced = new List<Map<String, Object>>{
                new Map<String, Object>{ 'Body' => Blob.valueOf('forced'), 'Description' => 'not a blob' }
        };

        // Act
        Test.startTest();
        List<Map<String, Blob>> captured = XFTY_BlobCarrier.capture(records, forced);
        Test.stopTest();

        // Assert
        Assert.areEqual('forced', captured[0].get('Body').toString());
        Assert.isFalse(captured[0].containsKey('Description'), 'a non-Blob forced value is not captured');
    }

    @IsTest
    static void testKeepOut_removesTheNamedFieldsFromTheRawMap() {
        // Arrange
        Map<String, Object> raw = new Map<String, Object>{ 'Body' => 'junk', 'Name' => 'f' };

        // Act
        Test.startTest();
        XFTY_BlobCarrier.keepOut(raw, new Set<String>{ 'Body' });
        Test.stopTest();

        // Assert
        Assert.isFalse(raw.containsKey('Body'));
        Assert.isTrue(raw.containsKey('Name'));
    }

    @IsTest
    static void testBlobFieldNames_listsThePopulatedBlobFields() {
        // Arrange
        Attachment record = new Attachment(Name = 'f', Body = Blob.valueOf('x'));

        // Act
        Test.startTest();
        Set<String> names = XFTY_BlobCarrier.blobFieldNames(record);
        Test.stopTest();

        // Assert
        Assert.isTrue(names.contains('Body'));
        Assert.isFalse(names.contains('Name'), 'a non-Blob field is not listed');
    }

    @IsTest
    static void testRestore_putsCapturedBlobsBackOntoTheRecords() {
        // Arrange
        List<SObject> records = new List<SObject>{ new Attachment(Name = 'f') };
        List<Map<String, Blob>> blobs = new List<Map<String, Blob>>{
                new Map<String, Blob>{ 'Body' => Blob.valueOf('back') }
        };

        // Act
        Test.startTest();
        XFTY_BlobCarrier.restore(records, blobs);
        Test.stopTest();

        // Assert
        Assert.areEqual('back', ((Attachment) records[0]).Body.toString());
    }
}
