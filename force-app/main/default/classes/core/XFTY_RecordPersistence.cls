/** Applies a generation's insert mode to its freshly built records. */
@IsTest
public class XFTY_RecordPersistence {

    public static void apply(XFTY_InsertModeEnum insertMode, List<SObject> records) {
        switch on insertMode {
            when NOW {
                insert records;
            }
            when MOCK {
                XFTY_IdMocker.addIds(records);
            }
        }
    }
}
