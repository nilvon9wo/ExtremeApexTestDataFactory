/**
 * Carries `Blob` fields across a `JSON.serialize` / `JSON.deserialize` round-trip.
 * The platform serialises a `Blob` to an object and then rejects it on a typed
 * deserialize, so `XFTY_SObjectInjector` captures every `Blob` off the records
 * (and any forced `Blob` value), keeps it out of the JSON, and re-applies it to
 * the result. A `Blob` on a nested (injected parent / child) record is dropped -
 * its field name is kept out of the JSON but there is nowhere to re-apply it.
 */
@IsTest
public class XFTY_BlobCarrier {

    /** The `Blob` values on each record, by field name - from the record and from `forcedValuesPerRow[row]`. */
    public static List<Map<String, Blob>> capture(
            List<SObject> records,
            List<Map<String, Object>> forcedValuesPerRow
    ) {
        List<Map<String, Blob>> byRow = new List<Map<String, Blob>>();
        for (Integer row = 0; row < records.size(); row++) {
            Map<String, Blob> here = blobsOf(records[row]);
            here.putAll(blobsAmong(forcedValuesPerRow[row]));
            byRow.add(here);
        }
        return byRow;
    }

    /** Remove `blobFields` from `rawRecord` so the round-trip does not choke on them. */
    public static void keepOut(Map<String, Object> rawRecord, Set<String> blobFields) {
        for (String field : blobFields) {
            rawRecord.remove(field);
        }
    }

    /** The `Blob` field names populated on `record`. */
    public static Set<String> blobFieldNames(SObject record) {
        return blobsOf(record).keySet();
    }

    /** Put the captured `Blob`s back onto the deserialised records. */
    public static void restore(List<SObject> records, List<Map<String, Blob>> blobsByRow) {
        for (Integer row = 0; row < records.size(); row++) {
            for (String field : blobsByRow[row].keySet()) {
                records[row].put(field, blobsByRow[row].get(field));
            }
        }
    }

    private static Map<String, Blob> blobsOf(SObject record) {
        return blobsAmong(record.getPopulatedFieldsAsMap());
    }

    private static Map<String, Blob> blobsAmong(Map<String, Object> valuesByField) {
        Map<String, Blob> blobs = new Map<String, Blob>();
        for (String field : valuesByField.keySet()) {
            if (valuesByField.get(field) instanceof Blob) {
                blobs.put(field, (Blob) valuesByField.get(field));
            }
        }
        return blobs;
    }
}
