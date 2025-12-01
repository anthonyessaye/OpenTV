/*
 * This file is auto-generated.  DO NOT MODIFY.
 * Using: /Users/anthonyessaye_podeo/Library/Android/sdk/build-tools/35.0.0/aidl -p/Users/anthonyessaye_podeo/Library/Android/sdk/platforms/android-36/framework.aidl -o/Users/anthonyessaye_podeo/Development/Android/OpenTV/openvpn/build/generated/aidl_source_output_dir/skeletonOvpn2Debug/out -I/Users/anthonyessaye_podeo/Development/Android/OpenTV/openvpn/src/main/aidl -I/Users/anthonyessaye_podeo/Development/Android/OpenTV/openvpn/src/ovpn2/aidl -I/Users/anthonyessaye_podeo/Development/Android/OpenTV/openvpn/src/skeleton/aidl -I/Users/anthonyessaye_podeo/Development/Android/OpenTV/openvpn/src/skeletonOvpn2/aidl -I/Users/anthonyessaye_podeo/Development/Android/OpenTV/openvpn/src/debug/aidl -I/Users/anthonyessaye_podeo/Development/Android/OpenTV/openvpn/src/skeletonOvpn2Debug/aidl -I/Users/anthonyessaye_podeo/.gradle/caches/8.14.2/transforms/c46293b73bfab632a9ca50f1c63e7ba4/transformed/core-1.16.0/aidl -I/Users/anthonyessaye_podeo/.gradle/caches/8.14.2/transforms/cdb9a786d74d8bcd6907f551af0955f0/transformed/versionedparcelable-1.1.1/aidl -d/var/folders/__/bd6kpcm91bz0f14z81v217th0000gn/T/aidl11773229258253116149.d /Users/anthonyessaye_podeo/Development/Android/OpenTV/openvpn/src/main/aidl/de/blinkt/openvpn/api/IOpenVPNStatusCallback.aidl
 */
package de.blinkt.openvpn.api;
/**
 * Example of a callback interface used by IRemoteService to send
 * synchronous notifications back to its clients.  Note that this is a
 * one-way interface so the server does not block waiting for the client.
 */
public interface IOpenVPNStatusCallback extends android.os.IInterface
{
  /** Default implementation for IOpenVPNStatusCallback. */
  public static class Default implements de.blinkt.openvpn.api.IOpenVPNStatusCallback
  {
    /** Called when the service has a new status for you. */
    @Override public void newStatus(java.lang.String uuid, java.lang.String state, java.lang.String message, java.lang.String level) throws android.os.RemoteException
    {
    }
    @Override
    public android.os.IBinder asBinder() {
      return null;
    }
  }
  /** Local-side IPC implementation stub class. */
  public static abstract class Stub extends android.os.Binder implements de.blinkt.openvpn.api.IOpenVPNStatusCallback
  {
    /** Construct the stub at attach it to the interface. */
    @SuppressWarnings("this-escape")
    public Stub()
    {
      this.attachInterface(this, DESCRIPTOR);
    }
    /**
     * Cast an IBinder object into an de.blinkt.openvpn.api.IOpenVPNStatusCallback interface,
     * generating a proxy if needed.
     */
    public static de.blinkt.openvpn.api.IOpenVPNStatusCallback asInterface(android.os.IBinder obj)
    {
      if ((obj==null)) {
        return null;
      }
      android.os.IInterface iin = obj.queryLocalInterface(DESCRIPTOR);
      if (((iin!=null)&&(iin instanceof de.blinkt.openvpn.api.IOpenVPNStatusCallback))) {
        return ((de.blinkt.openvpn.api.IOpenVPNStatusCallback)iin);
      }
      return new de.blinkt.openvpn.api.IOpenVPNStatusCallback.Stub.Proxy(obj);
    }
    @Override public android.os.IBinder asBinder()
    {
      return this;
    }
    @Override public boolean onTransact(int code, android.os.Parcel data, android.os.Parcel reply, int flags) throws android.os.RemoteException
    {
      java.lang.String descriptor = DESCRIPTOR;
      if (code >= android.os.IBinder.FIRST_CALL_TRANSACTION && code <= android.os.IBinder.LAST_CALL_TRANSACTION) {
        data.enforceInterface(descriptor);
      }
      if (code == INTERFACE_TRANSACTION) {
        reply.writeString(descriptor);
        return true;
      }
      switch (code)
      {
        case TRANSACTION_newStatus:
        {
          java.lang.String _arg0;
          _arg0 = data.readString();
          java.lang.String _arg1;
          _arg1 = data.readString();
          java.lang.String _arg2;
          _arg2 = data.readString();
          java.lang.String _arg3;
          _arg3 = data.readString();
          this.newStatus(_arg0, _arg1, _arg2, _arg3);
          break;
        }
        default:
        {
          return super.onTransact(code, data, reply, flags);
        }
      }
      return true;
    }
    private static class Proxy implements de.blinkt.openvpn.api.IOpenVPNStatusCallback
    {
      private android.os.IBinder mRemote;
      Proxy(android.os.IBinder remote)
      {
        mRemote = remote;
      }
      @Override public android.os.IBinder asBinder()
      {
        return mRemote;
      }
      public java.lang.String getInterfaceDescriptor()
      {
        return DESCRIPTOR;
      }
      /** Called when the service has a new status for you. */
      @Override public void newStatus(java.lang.String uuid, java.lang.String state, java.lang.String message, java.lang.String level) throws android.os.RemoteException
      {
        android.os.Parcel _data = android.os.Parcel.obtain();
        try {
          _data.writeInterfaceToken(DESCRIPTOR);
          _data.writeString(uuid);
          _data.writeString(state);
          _data.writeString(message);
          _data.writeString(level);
          boolean _status = mRemote.transact(Stub.TRANSACTION_newStatus, _data, null, android.os.IBinder.FLAG_ONEWAY);
        }
        finally {
          _data.recycle();
        }
      }
    }
    static final int TRANSACTION_newStatus = (android.os.IBinder.FIRST_CALL_TRANSACTION + 0);
  }
  /** @hide */
  public static final java.lang.String DESCRIPTOR = "de.blinkt.openvpn.api.IOpenVPNStatusCallback";
  /** Called when the service has a new status for you. */
  public void newStatus(java.lang.String uuid, java.lang.String state, java.lang.String message, java.lang.String level) throws android.os.RemoteException;
}
